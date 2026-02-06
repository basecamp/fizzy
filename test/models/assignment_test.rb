require "test_helper"

class AssignmentTest < ActiveSupport::TestCase
  test "create" do
    card = cards(:text)
    assignment = card.assignments.create!(assignee: users(:david), assigner: users(:jason))

    assert_equal users(:david), assignment.assignee
    assert_equal users(:jason), assignment.assigner
    assert_equal card, assignment.card
  end

  test "create cannot exceed assignee limit" do
    card = cards(:logo)
    board = card.board
    account = card.account

    card.assignments.delete_all

    Assignment::LIMIT.times do |i|
      identity = Identity.create!(email_address: "limit_test_#{i}@example.com")
      user = account.users.create!(identity: identity, name: "Limit Test User #{i}", role: :member)
      user.accesses.find_or_create_by!(board: board)
      card.assignments.create!(assignee: user, assigner: users(:david))
    end

    assert_equal Assignment::LIMIT, card.assignments.count

    identity = Identity.create!(email_address: "over_limit@example.com")
    extra_user = account.users.create!(identity: identity, name: "Over Limit User", role: :member)
    extra_user.accesses.find_or_create_by!(board: board)

    assignment = card.assignments.build(assignee: extra_user, assigner: users(:david))

    assert_not assignment.valid?
    assert_includes assignment.errors[:base], "Card already has the maximum of #{Assignment::LIMIT} assignees"
  end
end
