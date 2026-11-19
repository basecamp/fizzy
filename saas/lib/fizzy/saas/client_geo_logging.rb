#
#  Cloudflare tells us where a request comes from, in headers its "Add visitor location headers"
#  managed transform adds (CF-IPCountry is there even without it). Log them as client.geo, the
#  same fields Basecamp logs, so we can filter and group requests by place in Loki.
#
module Fizzy
  module Saas
    module ClientGeoLogging
      extend ActiveSupport::Concern

      included do
        before_action :log_client_geo
      end

      private
        def log_client_geo
          if geo = client_geo.presence
            logger.struct client: { geo: geo }
          end
        end

        def client_geo
          {
            country_iso_code: cloudflare_header("CF-IPCountry"),
            region_iso_code: cloudflare_header("CF-Region-Code"),
            city_name: cloudflare_header("CF-IPCity"),
            location: client_geo_location
          }.compact
        end

        def client_geo_location
          latitude = Float(cloudflare_header("CF-IPLatitude"), exception: false)
          longitude = Float(cloudflare_header("CF-IPLongitude"), exception: false)

          if latitude && longitude
            { lat: latitude, lon: longitude }
          end
        end

        # Header values arrive as binary, and city names can carry accents.
        def cloudflare_header(name)
          request.headers[name]&.dup&.force_encoding(Encoding::UTF_8)&.scrub&.presence
        end
    end
  end
end
