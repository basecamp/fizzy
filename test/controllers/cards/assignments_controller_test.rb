require "test_helper"

class Bubbles::AssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_bubble_assignment_url(bubbles(:logo))
    assert_response :success
  end

  test "create" do
    assert_changes "bubbles(:logo).assigned_to?(users(:david))", from: false, to: true do
      post bubble_assignments_url(bubbles(:logo)), params: { assignee_id: users(:david).id }, as: :turbo_stream
    end
    assert_response :success

    assert_changes "bubbles(:logo).assigned_to?(users(:david))", from: true, to: false do
      post bubble_assignments_url(bubbles(:logo)), params: { assignee_id: users(:david).id }, as: :turbo_stream
    end
    assert_response :success
  end
end
