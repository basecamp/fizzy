require "test_helper"
require "active_storage/service/s3_service"

class ActiveStorageLogSubscriberFilteredUrlsTest < ActiveSupport::TestCase
  setup do
    @service = ActiveStorage::Service::S3Service.new \
      bucket: "made-up-bucket", region: "us-east-1", endpoint: "https://storage.example.com", force_path_style: true,
      access_key_id: "made-up-access-key-id", secret_access_key: "made-up-secret-access-key"
    @service.name = :made_up
  end

  test "a generated download URL is logged without its signature" do
    url, logged = log_generated_url { @service.url("made-up-key", expires_in: 5.minutes, filename: ActiveStorage::Filename.new("report.pdf"), disposition: :inline, content_type: "application/pdf") }

    assert_logged_without_signature url, logged
  end

  test "a generated direct upload URL is logged without its signature" do
    url, logged = log_generated_url { @service.url_for_direct_upload("made-up-key", expires_in: 5.minutes, content_type: "application/pdf", content_length: 1, checksum: "made-up-checksum") }

    assert_logged_without_signature url, logged
  end

  test "a fragment is kept apart from the filtered query" do
    _, logged = log_generated_url do
      ActiveSupport::Notifications.instrument "service_url.active_storage", key: "made-up-key", service: "Made-up",
        url: "https://storage.example.com/made-up-key?X-Amz-Signature=made-up-signature#page=2"
    end

    assert_includes logged, "(https://storage.example.com/made-up-key?X-Amz-Signature=[FILTERED]#page=2)"
  end

  private
    def log_generated_url(&block)
      log = StringIO.new
      original_logger, ActiveStorage.logger = ActiveStorage.logger, ActiveSupport::Logger.new(log)

      url = Rails.event.with_debug(&block)
      [ url, log.string.lines.grep(/Generated URL for file at key: made-up-key/).sole ]
    ensure
      ActiveStorage.logger = original_logger
    end

    def assert_logged_without_signature(url, logged)
      signature = Rack::Utils.parse_query(URI.parse(url).query).fetch("X-Amz-Signature")
      assert_match(/\A\h{64}\z/, signature, "the generated URL keeps its signature")

      assert_includes logged, "https://storage.example.com/made-up-bucket/made-up-key?"
      assert_includes logged, "X-Amz-Signature=[FILTERED]"
      assert_includes logged, "X-Amz-Expires=300"
      assert_not_includes logged, signature
    end
end
