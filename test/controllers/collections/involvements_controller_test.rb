require "test_helper"

class Collections::InvolvementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    collection = collections(:writebook)
    collection.access_for(users(:kevin)).access_only!

    assert_changes -> { collection.access_for(users(:kevin)).involvement }, from: "access_only", to: "watching" do
      put collection_involvement_url(collection, involvement: "watching")
    end

    assert_response :success
  end
end
