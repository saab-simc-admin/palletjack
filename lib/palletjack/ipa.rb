require 'curb'
require 'resolv'
require 'json'

class PalletJack
  class Ipa

    class Request

      # Save the curl object, when we login we will recive a session
      # cookie that is saved within the @@curl objects cookie cache.
      @@curl = nil
      @@session_init = false

      @@ipa_url = nil

      def initialize(payload)
        @payload = payload.to_json
        if @@curl == nil then
          @@curl = Curl::Easy.new # TODO: Test
        end
        if @@ipa_url == nil then
          _set_server
        end
        self._make_request()
      end

      def _set_server

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

      def _make_request

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

        puts "DEBUG: Request: " + @payload

        @@curl.http_post(@payload)

        @body = @@curl.body_str

        puts "DEBUG: Response:" + @body

      end

      def response
        JSON.parse(@body)
      end

      def raw_response
        @body
      end

    end

    class Command

      @@api_version = "2.156"

      def initialize(method, name=nil, params={})
        @method = method
        @name = name
        @params = params
        @payload = _build_payload
        @request = PalletJack::Ipa::Request.new(@payload)
        @response = @request.response
      end


      def _build_payload

        if not @params["all"] then
          @params["all"] = false
        end
        if not @params["raw"] then
          @params["raw"] = true
        end
        if not @params["version"] then
          @params["version"] = @@api_version
        end

        _name = []
        if @name then
          if @name.is_a? Array
            _name = @name
          elsif @name.is_a? String
            _name = [ @name ]
          end
        end

        @payload = {
          "id"     => 0,
          "method" => @method,
          "params" => [
            [ @name ],
            @params
          ]


        }
      end 

      def server_version
        @response['version']
      end

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

      def count
        self.results.count
      end

    end

  end
end
