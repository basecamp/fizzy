require "test_helper"

class Cards::AssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_card_assignment_url(cards(:logo))
    assert_response :success
  end

  test "create" do
    assert_changes "cards(:logo).assigned_to?(users(:david))", from: false, to: true do
      post card_assignments_url(cards(:logo)), params: { assignee_id: users(:david).id }, as: :turbo_stream
    end
    assert_response :success

    assert_changes "cards(:logo).assigned_to?(users(:david))", from: true, to: false do
      post card_assignments_url(cards(:logo)), params: { assignee_id: users(:david).id }, as: :turbo_stream
    end
    assert_response :success
  end
end
