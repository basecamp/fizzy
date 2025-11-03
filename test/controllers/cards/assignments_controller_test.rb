require "test_helper"

class Cards::AssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_card_assignment_path(cards(:logo))
    assert_response :success
  end

  test "create" do
    assert_changes "cards(:logo).assigned_to?(users(:david))", from: false, to: true do
      post card_assignments_path(cards(:logo)), params: { assignee_id: users(:david).id }, as: :turbo_stream
      assert_meta_replaced(cards(:logo))
    end

    assert_changes "cards(:logo).assigned_to?(users(:david))", from: true, to: false do
      post card_assignments_path(cards(:logo)), params: { assignee_id: users(:david).id }, as: :turbo_stream
      assert_meta_replaced(cards(:logo))
    end
  end

  private
    def assert_meta_replaced(card)
      assert_turbo_stream action: :replace, target: dom_id(card, :meta)
    end
end
