require "test_helper"

class Buckets::InvolvementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    bucket = buckets(:writebook)
    bucket.access_for(users(:kevin)).access_only!

    assert_changes -> { bucket.access_for(users(:kevin)).involvement }, from: "access_only", to: "watching" do
      put bucket_involvement_url(bucket, involvement: "watching")
    end

    assert_response :success
  end
end
