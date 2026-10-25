require "test_helper"

class StorageRedirectLoggingTest < ActionDispatch::IntegrationTest
  setup do
    @blob = Current.with(session: sessions(:david)) do
      cards(:logo).image.attach io: file_fixture("moon.jpg").open, filename: "test.jpg", content_type: "image/jpeg"
      cards(:logo).image.blob
    end
  end

  test "a redirect to presigned storage logs the location without its signature" do
    location = "https://storage.example.com/made-up-bucket/made-up-key?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=300&X-Amz-Signature=made-up-signature"
    ActiveStorage::Blob.any_instance.stubs(:url).returns(location)

    log = StringIO.new
    ActionController::LogSubscriber.logger = ActiveSupport::Logger.new(log)

    sign_in_as :david
    get rails_blob_path(@blob, disposition: :inline)
    assert_redirected_to location

    assert_includes log.string, "Redirected to https://storage.example.com/made-up-bucket/made-up-key?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=300&X-Amz-Signature=[FILTERED]"
    assert_not_includes log.string, "made-up-signature"
  ensure
    ActionController::LogSubscriber.logger = nil
  end
end
