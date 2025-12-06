require "test_helper"

class Users::MyAvatarControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "show own initials" do
    get my_avatar_path
    assert_match "image/svg+xml", @response.content_type
    assert_match "private", @response.headers["Cache-Control"]
    assert_match "must-revalidate", @response.headers["Cache-Control"]
  end

  test "show own image redirects to the blob url" do
    users(:david).avatar.attach(io: File.open(file_fixture("moon.jpg")), filename: "moon.jpg", content_type: "image/jpeg")
    assert users(:david).avatar.attached?

    get my_avatar_path

    assert_redirected_to rails_blob_url(users(:david).avatar.variant(:thumb), disposition: "inline")
    assert_match "private", @response.headers["Cache-Control"]
    assert_match "must-revalidate", @response.headers["Cache-Control"]
  end

  test "requires authentication" do
    sign_out

    get my_avatar_path

    assert_response :redirect
  end
end
