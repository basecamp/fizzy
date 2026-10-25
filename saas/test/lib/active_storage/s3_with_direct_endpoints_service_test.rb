require "test_helper"
require "active_storage/service/s3_with_direct_endpoints_service"

class ActiveStorage::S3WithDirectEndpointsServiceTest < ActiveSupport::TestCase
  setup do
    @service = ActiveStorage::Service::S3WithDirectEndpointsService.new **service_options

    @key = "test-file.txt"
  end

  test "direct download URLs use direct_download_endpoint" do
    freeze_time do
      options = { expires_in: 5.minutes, filename: ActiveStorage::Filename.new("test.txt"), disposition: :inline, content_type: "text/plain" }
      assert_equal @service.direct_download_service.url(@key, **options), @service.url(@key, **options)
    end
  end

  test "direct upload URLs use direct_upload_endpoint" do
    freeze_time do
      options = { expires_in: 5.minutes, content_type: "text/plain", content_length: 1024, checksum: "abc123" }
      assert_equal @service.direct_upload_service.url_for_direct_upload(@key, **options), @service.url_for_direct_upload(@key, **options)
    end
  end

  test "headers for direct upload are generated correctly" do
    freeze_time do
      options = { content_type: "text/plain", checksum: "abc123", filename: ActiveStorage::Filename.new("test.txt"), disposition: :attachment }
      assert_equal @service.direct_upload_service.headers_for_direct_upload(@key, **options), @service.headers_for_direct_upload(@key, **options)
    end
  end

  test "direct upload URLs are signed with the write-only credential" do
    freeze_time do
      options = { expires_in: 5.minutes, content_type: "text/plain", content_length: 1024, checksum: "abc123" }
      write_only_signer = ActiveStorage::Service::S3Service.new \
        **service_options.slice(:bucket, :region, :force_path_style),
        endpoint: "https://storage-uploads.example.com", access_key_id: "write-only-key", secret_access_key: "write-only-secret"
      url = @service.url_for_direct_upload(@key, **options)

      assert_equal "write-only-key", signing_key_id(url)
      assert_equal write_only_signer.url_for_direct_upload(@key, **options), url
    end
  end

  test "download URLs are signed with the primary credential" do
    url = @service.url(@key, expires_in: 5.minutes, filename: ActiveStorage::Filename.new("test.txt"), disposition: :inline, content_type: "text/plain")

    assert_equal "test-key", signing_key_id(url)
  end

  test "server-side operations are signed with the primary credential" do
    requests = []
    stub_request(:any, %r{\Ahttps://storage(-uploads)?\.(internal\.)?example\.com/}).to_return do |request|
      requests << request
      s3_response_for(request)
    end

    @service.upload @key, StringIO.new("hello"), checksum: OpenSSL::Digest::MD5.base64digest("hello")
    @service.exist? @key
    @service.download @key
    @service.compose [ @key ], "composed.txt"
    @service.delete @key

    assert_equal %i[ delete get head post put ], requests.map(&:method).uniq.sort
    assert requests.all? { it.uri.host == "storage.internal.example.com" }
    assert_equal [ "test-key" ], requests.map { it.headers["Authorization"][/Credential=([^\/]+)\//, 1] }.uniq
  end

  test "a direct upload endpoint without the write-only credential refuses to build" do
    error = assert_raises ArgumentError do
      ActiveStorage::Service::S3WithDirectEndpointsService.new \
        **service_options.except(:direct_upload_access_key_id, :direct_upload_secret_access_key)
    end
    assert_match "direct_upload_access_key_id", error.message

    assert_raises ArgumentError do
      ActiveStorage::Service::S3WithDirectEndpointsService.new **service_options, direct_upload_secret_access_key: ""
    end
  end

  test "without a direct upload endpoint, uploads sign with the primary credential as before" do
    service = ActiveStorage::Service::S3WithDirectEndpointsService.new \
      **service_options.except(:direct_upload_endpoint, :direct_upload_access_key_id, :direct_upload_secret_access_key)

    assert_nil service.direct_upload_service
    assert_equal "test-key", signing_key_id(service.url_for_direct_upload(@key, expires_in: 5.minutes, content_type: "text/plain", content_length: 1024, checksum: "abc123"))
  end

  test "storage.yml presigns direct uploads with the ACTIVE_STORAGE_DIRECT_UPLOAD credential" do
    credentials = {
      "ACTIVE_STORAGE_ACCESS_KEY_ID" => "test-key", "ACTIVE_STORAGE_SECRET_ACCESS_KEY" => "test-secret",
      "ACTIVE_STORAGE_DIRECT_UPLOAD_ACCESS_KEY_ID" => "write-only-key", "ACTIVE_STORAGE_DIRECT_UPLOAD_SECRET_ACCESS_KEY" => "write-only-secret" }
    previous = ENV.to_h.slice(*credentials.keys)
    ENV.update credentials
    service = ActiveStorage::Service.configure :purestorage, \
      ActiveSupport::ConfigurationFile.parse(Fizzy::Saas::Engine.root.join("config/storage.yml"))

    assert_equal "write-only-key", signing_key_id(service.url_for_direct_upload(@key, expires_in: 5.minutes, content_type: "text/plain", content_length: 1024, checksum: "abc123"))
    assert_equal "test-key", signing_key_id(service.url(@key, expires_in: 5.minutes, filename: ActiveStorage::Filename.new("test.txt"), disposition: :inline, content_type: "text/plain"))
  ensure
    credentials.each_key { ENV.delete it }
    ENV.update previous
  end

  private
    def service_options
      { bucket: "test-bucket",
        endpoint: "https://storage.internal.example.com",
        direct_download_endpoint: "https://storage-downloads.example.com",
        direct_upload_endpoint: "https://storage-uploads.example.com",
        region: "us-east-1",
        access_key_id: "test-key",
        secret_access_key: "test-secret",
        direct_upload_access_key_id: "write-only-key",
        direct_upload_secret_access_key: "write-only-secret",
        force_path_style: true }
    end

    def signing_key_id(url)
      Rack::Utils.parse_query(URI.parse(url).query).fetch("X-Amz-Credential").split("/").first
    end

    def s3_response_for(request)
      case [ request.method, request.uri.query.to_s ]
      in [ :post, /uploads/ ]
        { body: "<InitiateMultipartUploadResult><UploadId>upload-id</UploadId></InitiateMultipartUploadResult>" }
      in [ :post, /uploadId/ ]
        { body: "<CompleteMultipartUploadResult><ETag>\"etag\"</ETag></CompleteMultipartUploadResult>" }
      in [ :get, _ ]
        { body: "hello", headers: { "Content-Length" => "5", "Content-Range" => "bytes 0-4/5" } }
      in [ :delete, _ ]
        { status: 204 }
      else
        { headers: { "ETag" => "\"etag\"", "Content-Length" => "0" } }
      end
    end
end
