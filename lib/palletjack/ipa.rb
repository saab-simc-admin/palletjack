require 'curb'
require 'resolv'
require 'json'

class PalletJack
  class Ipa

    # Helper class for the <tt>PalletJack::Ipa::Command</tt> class
    #
    # This class is initialized with a payload dict that resembles
    # the data to be sent to the JSON-RPC endpoint. The class will
    # take care of session management troughout the lifetime of the
    # application.
    #
    # Authentication is done trough GSSAPI. It is assumed that whoever
    # running the script has a valid kerberos credential.
    #
    # The endpoint is automatically determined and it is assumed that
    # the FQDN of the current machine is the same as the IPA domain.
    #
    # See the Red Hat documentation about JSON-RPC for more info:
    # https://access.redhat.com/articles/2728021
    #

    class Request

      # Save the curl object, when we login we will recive a session
      # cookie that is saved within the @@curl objects cookie cache.
      @@curl = nil
      @@session_init = false

      @@ipa_url = nil

      # Perform a HTTP request against the JSON-RPC endpoint of a IPA server.
      def initialize(payload, debug = false)
        @payload = payload.to_json
        @debug = debug
        if @@curl == nil then
          @@curl = Curl::Easy.new
        end
        if @@ipa_url == nil then
          _set_server
        end
        self._make_request()
      end

      def _set_server # :nodoc:

        domainname_base = `hostname -d`.strip()

        lowest_prio = 65536
        target_server = nil

        resolver = Resolv::DNS.new
        resolver.each_resource("_ldap._tcp." + domainname_base, Resolv::DNS::Resource::IN::SRV) do |srv|
          if srv.priority < lowest_prio then
            target_server = srv.target.to_s
          end
        end

        @@ipa_url = "https://" + target_server + "/ipa"
      end

      def _make_request # :nodoc:

        # Authenticate to request a new session
        # By creating a session and then using the session ID, we do not need
        # to do a GSSAPI Authentication for every API request made within the
        # same script.
        if @@session_init == false then
          # The session is automatically initialized if a request is made towards the API
          _login_payload = {
                "id"     => 0, 
                "method" => "ping",
                "params" => [ [], {} ]
          }

          # This should act as default settings troughout the session
          @@curl.set(:HTTPAUTH, Curl::CURLAUTH_GSSNEGOTIATE)
          @@curl.username = ':'
          @@curl.enable_cookies = true
          @@curl.verbose = false
          @@curl.headers["Referer"] = @@ipa_url + "/json"
          @@curl.headers['Content-Type'] = "application/json"
          @@curl.url = @@ipa_url + "/json"
          @@curl.http_post(_login_payload.to_json)
          _session_result = JSON.parse(@@curl.body_str)

          if _session_result['error'] != nil then
            puts "Error authentication!"
          end
          @@curl.url = @@ipa_url + "/session/json"
          #@@curl.set(:HTTPAUTH, Curl::CURLAUTH_NONE) # Reset auth, rely on cookie
        end

        if @debug then
          puts "DEBUG: Request: " + @payload
        end

        @@curl.http_post(@payload)

        @body = @@curl.body_str

        if @debug then
          puts "DEBUG: Response:" + @body
        end

      end

      # Return a +hash+ with the command response
      def response
        JSON.parse(@body)
      end

      # Return a +string+ with the command reponse JSON.
      def raw_response
        @body
      end

    end

    class Command

      @@api_version = "2.156"

      # Execute RPC Commands on a IPA server.
      #
      # :call-seq:
      #   new(method [,pos1 [,params]]) -> command
      #
      # This class will take a method name, positional parameters and named
      # parameters and make a JSON-RPC request against a IPA server.
      #
      # <tt>ipa -vv <command> [params]</tt> may be used to see an example of the data
      # structure used by the API. In general the API parameters is very similar
      # to the command line tool.
      #
      # === Attributes
      #
      # * +method+ - The JSON-RPC Method to call
      # * +name+ - The positional parameters to the method. Can be an array or string.
      # * +params+ - Named parameters to the method.
      # * +debug+ - Enable debugging output, default: false
      #
      # Examples:
      #   <tt>PalletJack::Ipa::Command.new("host_add", "new_system", { ip_address: "192.168.13.37" })</tt>
      #   <tt>PalletJack::Ipa::Command.new("host_find")</tt>
      def initialize(method, name=nil, params={}, debug = false)
        @method = method
        @name = name
        @params = params
        @payload = _build_payload
        @request = PalletJack::Ipa::Request.new(@payload, debug)
        @debug = debug
        @response = @request.response
      end


      def _build_payload # :nodoc:

        # Add defaults for required parameters
        if not @params["all"] then
          @params["all"] = false
        end
        if not @params["raw"] then
          @params["raw"] = true
        end
        if not @params["version"] then
          @params["version"] = @@api_version
        end

        # The positional argument always need to be an array in the payload.
        _name = []
        if @name then
          if @name.is_a? Array
            _name = @name
          else
            _name = [ @name ]
          end
        end

        # Construct the payload.
        @payload = {
          "id"     => 0,
          "method" => @method,
          "params" => [
            _name,
            @params
          ]


        }
      end 

      # The API version from the server.
      def server_version
        @response['version']
      end

      # The response given by the command.
      #
      # This method will always return an array. Single results will be
      # converted to a single element array.
      #
      #--
      # TODO: Implement proper error handling.
      # Currently handles empty results badly.
      def results
        _res_b = @response['result']
        if _res_b['result'] then
          if _res_b['result'].is_a? Array then
            _res_out =_res_b['result']
           else
             _res_out = [ _res_b['result'] ]
           end
        else
          puts "ERROR: No result"
        end

        if block_given? then
          _res_out.each do |i|
            yield i
          end
        end

        _res_out
      end

      # The amount of results returned
      def count
        self.results.count
      end

      # Was there an error?
      def error?
        if @result['error'] then
          true
        else
          false
        end
      end

      # The error code returned by the API.
      def error_code
        if self.error? then
          @result['error']['code']
        else
          nil
        end
      end

      # The error short name returned by the API.
      def error_name
        if self.error? then
          @result['error']['name']
        else
          nil
        end
      end

      # Descriptive error message returned by the API.
      def error_message
        if self.error? then
          @result['error']['message']
        else
          nil
        end
      end
    end

  end
end
