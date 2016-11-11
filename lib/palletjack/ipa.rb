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
      def initialize(payload)
        @payload = payload.to_json
        @@curl ||= Curl::Easy.new
        @@ipa_url ||= get_server
        make_request()
      end

      def get_server

        domainname_base = `hostname -d`.strip()

        lowest_prio = 65536
        target_server = nil

        resolver = Resolv::DNS.new
        resolver.each_resource("_ldap._tcp." + domainname_base, Resolv::DNS::Resource::IN::SRV) do |srv|
          if srv.priority < lowest_prio then
            target_server = srv.target.to_s
          end
        end

        "https://" + target_server + "/ipa"
      end
      private :get_server

      def make_request

        # Authenticate to request a new session
        # By creating a session and then using the session ID, we do not need
        # to do a GSSAPI Authentication for every API request made within the
        # same script.
        unless @@session_init then
          # The session is automatically initialized if a request is made towards the API
          login_payload = {
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
          @@curl.http_post(login_payload.to_json)
          session_result = JSON.parse(@@curl.body_str)

          if session_result['error'] then
            puts "Error authentication!"
          end
          @@curl.url = @@ipa_url + "/session/json"
          #@@curl.set(:HTTPAUTH, Curl::CURLAUTH_NONE) # Reset auth, rely on cookie
        end

        if debug? then
          puts "DEBUG: Request: " + @payload
        end

        @@curl.http_post(@payload)

        @body = @@curl.body_str

        if debug? then
          puts "DEBUG: Response:" + @body
        end

      end
      private :make_request

      # Return a +hash+ with the command response
      def response
        JSON.parse(@body)
      end

      # Return a +string+ with the command reponse JSON.
      def raw_response
        @body
      end

      def self.debug=(maybe)
        @@debug = maybe
      end

      def self.debug
        @@debug ||= false
      end

      def debug?
        self.class.debug
      end
      private :debug?

    end

    class Command

      @@api_version = "2.156"

      # Execute RPC Commands on a IPA server.
      #
      # :call-seq:
      #   new(method[, arg, ...]) -> obj
      #   new(method[, arg, ...], key: value, ...) -> obj
      #   new(method, key: value, ...) -> obj
      #
      # Takes the JSON-RPC method as the first parameter. Optional parameters
      # are positional arguments to the method and named parameters are passed
      # as key/value pairs.
      #
      # <tt>ipa -vv <command> ...</tt> can be used to see an example of the
      # data structure used by the API. Also see the Red Hat documentation of
      # the JSON-RPC API: https://access.redhat.com/articles/2728021
      #
      # Examples:
      #   PalletJack::Ipa::Command.new('host_find')
      #   PalletJack::Ipa::Command.new('dnsrecord_find', 'ipa.example.com')
      #   PalletJack::Ipa::Command.new('host_find', nsosversion: 'RHEL7')
      #   PalletJack::Ipa::Command.new('host_add', 'new-system', ip_address: '192.168.13.37' )
      def initialize(method, *args, **kwargs)
        @method = method
        @args = args
        @kwargs = kwargs
        @payload = build_payload
        @request = PalletJack::Ipa::Request.new(@payload)
        @response = @request.response
      end


      def build_payload

        # Add defaults for required parameters
        if not @kwargs[:all] then
          @kwargs[:all] = false
        end
        if not @kwargs[:raw] then
          @kwargs[:raw] = true
        end
        if not @kwargs[:version] then
          @kwargs[:version] = @@api_version
        end

        # The positional argument always need to be an array in the payload.
        name = []
        if @args then
          if @args.is_a? Array
            name = @args
          else
            name = [ @args ]
          end
        end

        # Construct the payload.
        @payload = {
          "id"     => 0,
          "method" => @method,
          "params" => [
            name,
            @kwargs
          ]


        }
      end
      private :build_payload

      # The API version from the server.
      def server_version
        @response['version']
      end

      # The response given by the command.
      #
      # Returns +nil+ or an +array+ of +hash+.
      #
      # :call-seq:
      #   results -> array
      #   results { |item| block }
      #
      #--
      # TODO: Implement proper error handling.
      def results
        res_b = @response['result']
        res_out = nil
        if res_b['result'] then
          if res_b['result'].is_a? Array then
            res_out =res_b['result']
           else
             res_out = [ res_b['result'] ]
           end
        else
          puts "ERROR: No result"
        end

        if res_out and block_given? then
          res_out.each do |i|
            yield i
          end
        end

        res_out
      end

      # The amount of results returned
      def count
        self.results.count
      end

      # Was there an error?
      def error?
        not @response['error'].nil?
      end

      # The error code returned by the API.
      def error_code
        if self.error? then
          @response['error']['code']
        end
      end

      # The error short name returned by the API.
      def error_name
        if self.error? then
          @response['error']['name']
        end
      end

      # Descriptive error message returned by the API.
      def error_message
        if self.error? then
          @response['error']['message']
        end
      end

    end
  end
end
