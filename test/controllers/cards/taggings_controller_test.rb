require "test_helper"

class Bubbles::TaggingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_bubble_tagging_url(bubbles(:logo))
    assert_response :success
  end

  test "toggle tag on" do
    assert_changes "bubbles(:logo).tagged_with?(tags(:mobile))", from: false, to: true do
      post bubble_taggings_url(bubbles(:logo)), params: { tag_title: tags(:mobile).title }, as: :turbo_stream
    end
    assert_response :success
  end

  test "toggle tag off" do
    assert_changes "bubbles(:logo).tagged_with?(tags(:web))", from: true, to: false do
      post bubble_taggings_url(bubbles(:logo)), params: { tag_title: tags(:web).title }, as: :turbo_stream
    end
    assert_response :success
  end
end
