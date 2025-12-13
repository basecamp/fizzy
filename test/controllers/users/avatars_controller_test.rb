require "test_helper"

class Users::AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "show system user" do
    get user_avatar_path(users(:system))

    assert_response :redirect
    assert_redirected_to ActionController::Base.helpers.image_path("system_user.png")
  end

  test "show initials with public caching" do
    get user_avatar_path(users(:david))
    assert_match "image/svg+xml", @response.content_type
    assert @response.cache_control[:public]
    assert_equal 30.minutes.to_s, @response.cache_control[:max_age]
  end

  test "show own image redirects to the blob url" do
    users(:david).avatar.attach(io: File.open(file_fixture("moon.jpg")), filename: "moon.jpg", content_type: "image/jpeg")
    assert users(:david).avatar.attached?

    get user_avatar_path(users(:david))

    assert_redirected_to rails_blob_url(users(:david).avatar_thumbnail, disposition: "inline")
  end

  test "show other image redirects to the blob url" do
    users(:kevin).avatar.attach(io: File.open(file_fixture("moon.jpg")), filename: "moon.jpg", content_type: "image/jpeg")
    assert users(:kevin).avatar.attached?

    get user_avatar_path(users(:kevin))

    assert_redirected_to rails_blob_url(users(:kevin).avatar_thumbnail, disposition: "inline")
  end

  test "delete self" do
    delete user_avatar_path(users(:david))
    assert_redirected_to users(:david)
  end

  test "unable to delete other" do
    delete user_avatar_path(users(:kevin))
    assert_response :forbidden
  end
end
