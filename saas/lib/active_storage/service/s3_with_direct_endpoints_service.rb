require "active_storage/service/s3_service"

module ActiveStorage
  class Service
    # S3 storage with distinct endpoints for direct uploads, downloads,
    # and backend service operations.
    #
    # This allows us to direct browser uploads and downloads to distinct
    # Cloudflare sites, F5 virtual servers, etc.
    #
    # Provide direct_upload_endpoint and direct_download_endpoint to
    # use separate URLs. Both default to the primary service endpoint.
    #
    # Direct upload URLs are presigned with their own credential, which
    # may only write objects (s3:PutObject), so a URL handed to a browser
    # carries no more authority than the upload it's for. Everything else,
    # including server-side uploads, composes, downloads and deletes, uses
    # the primary credential.
    #
    # A direct_upload_endpoint requires direct_upload_access_key_id and
    # direct_upload_secret_access_key: we refuse to sign browser uploads
    # with the primary credential rather than fall back to it.
    class S3WithDirectEndpointsService < S3Service
      attr_reader :direct_upload_service, :direct_download_service

      def initialize(endpoint:, direct_upload_endpoint: nil, direct_download_endpoint: nil,
          direct_upload_access_key_id: nil, direct_upload_secret_access_key: nil, **options)
        super endpoint:, **options

        if direct_upload_endpoint
          if direct_upload_access_key_id.blank? || direct_upload_secret_access_key.blank?
            raise ArgumentError, "direct_upload_endpoint requires direct_upload_access_key_id and " \
              "direct_upload_secret_access_key: a write-only credential for signing direct uploads"
          end

          @direct_upload_service = S3Service.new **options, endpoint: direct_upload_endpoint,
            access_key_id: direct_upload_access_key_id, secret_access_key: direct_upload_secret_access_key
        end

        @direct_download_service = S3Service.new(**options, endpoint: direct_download_endpoint) if direct_download_endpoint
      end

      def url_for_direct_upload(...)
        if direct_upload_service
          direct_upload_service.url_for_direct_upload(...)
        else
          super
        end
      end

      def headers_for_direct_upload(...)
        if direct_upload_service
          direct_upload_service.headers_for_direct_upload(...)
        else
          super
        end
      end

      private
        def private_url(key, **kwargs)
          if direct_download_service
            direct_download_service.send(:private_url, key, **kwargs)
          else
            super
          end
        end
    end
  end
end
