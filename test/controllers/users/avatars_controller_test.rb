require "test_helper"

class Users::AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "show self without caching" do
    get user_avatar_path(users(:david))
    assert_match "image/svg+xml", @response.content_type
    assert_nil @response.cache_control[:max_age]
  end

  test "show other with caching" do
    get user_avatar_path(users(:kevin))
    assert_match "image/svg+xml", @response.content_type
    assert_equal 30.minutes.to_s, @response.cache_control[:max_age]
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
