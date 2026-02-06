require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index as JSON" do
    tags = users(:kevin).account.tags.alphabetically

    get tags_path, as: :json
    assert_response :success
    assert_equal tags.count, @response.parsed_body.count
    assert_equal tags.pluck(:title), @response.parsed_body.pluck("title")
  end
end
