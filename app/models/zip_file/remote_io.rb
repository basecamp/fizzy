class ZipFile::RemoteIO < ZipKit::RemoteIO
  protected
    def request_range(range)
      with_http do |http|
        request = Net::HTTP::Get.new(@uri)
        request.range = range
        response = http.request(request)

        case response.code
        when "206", "200"
          response.body
        else
          raise "Remote at #{@uri} replied with code #{response.code}"
        end
      end
    end

    def request_object_size
      with_http do |http|
        request = Net::HTTP::Get.new(@uri)
        request.range = 0..0
        response = http.request(request)

        case response.code
        when "206"
          content_range_header_value = response["Content-Range"]
          content_range_header_value.split("/").last.to_i
        when "200"
          response["Content-Length"].to_i
        else
          raise "Remote at #{@uri} replied with code #{response.code}"
        end
      end
    end

  private
    def with_http
      http = Net::HTTP.new(@uri.hostname, @uri.port)
      http.use_ssl = @uri.scheme == "https"
      # FIXME: Disable SSL verification for now to avoid issues with our self-signed certificates for PureStorage
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.start { yield http }
    end
end
