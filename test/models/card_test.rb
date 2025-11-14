require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "create assigns a number to the card" do
    user = users(:david)
    board = boards(:writebook)
    account = board.account
    card = nil

    assert_difference -> { account.reload.cards_count }, +1 do
      card = Card.create!(title: "Test", board: board, creator: user)
    end

    assert_equal account.reload.cards_count, card.number
  end

  test "capturing messages" do
    assert_difference -> { cards(:logo).comments.count }, +1 do
      cards(:logo).comments.create!(body: "Agreed.")
    end

    assert_equal "Agreed.", cards(:logo).comments.last.body.to_plain_text.chomp
  end

  test "assignment states" do
    assert cards(:logo).assigned_to?(users(:kevin))
    assert_not cards(:logo).assigned_to?(users(:david))
  end

  test "assignment toggling" do
    assert cards(:logo).assigned_to?(users(:kevin))

    assert_difference({ -> { cards(:logo).assignees.count } => -1, -> { Event.count } => +1 }) do
      cards(:logo).toggle_assignment users(:kevin)
    end
    assert_not cards(:logo).assigned_to?(users(:kevin))
    unassign_event = Event.last
    assert_equal "card_unassigned", unassign_event.action
    assert_equal [ users(:kevin) ], unassign_event.assignees

    assert_difference %w[ cards(:logo).assignees.count Event.count ], +1 do
      cards(:logo).toggle_assignment users(:kevin)
    end
    assert cards(:logo).assigned_to?(users(:kevin))
    assign_event = Event.last
    assert_equal "card_assigned", assign_event.action
    assert_equal [ users(:kevin) ], assign_event.assignees
  end

  test "tagged states" do
    assert cards(:logo).tagged_with?(tags(:web))
    assert_not cards(:logo).tagged_with?(tags(:mobile))
  end

  test "tag toggling" do
    assert cards(:logo).tagged_with?(tags(:web))

    assert_difference "cards(:logo).taggings.count", -1 do
      cards(:logo).toggle_tag_with tags(:web).title
    end
    assert_not cards(:logo).tagged_with?(tags(:web))

    assert_difference "cards(:logo).taggings.count", +1 do
      cards(:logo).toggle_tag_with tags(:web).title
    end
    assert cards(:logo).tagged_with?(tags(:web))

    assert_difference %w[ cards(:logo).taggings.count Tag.count ], +1 do
      cards(:logo).toggle_tag_with "prioritized"
    end
    assert_equal "prioritized", cards(:logo).taggings.last.tag.title
  end

  test "closed" do
    assert_equal [ cards(:shipping) ], Card.closed
  end

  test "open" do
    assert_equal cards(:logo, :layout, :text, :buy_domain).to_set, Card.open.to_set
  end

  test "card_unassigned" do
    assert_equal cards(:shipping, :text, :buy_domain).to_set, Card.unassigned.to_set
  end

  test "assigned to" do
    assert_equal cards(:logo, :layout).to_set, Card.assigned_to(users(:jz)).to_set
  end

  test "assigned by" do
    assert_equal cards(:layout, :logo).to_set, Card.assigned_by(users(:david)).to_set
  end

  test "in board" do
    new_board = Board.create! name: "New Board", creator: users(:david)
    assert_equal cards(:logo, :shipping, :layout, :text, :buy_domain).to_set, Card.where(board: boards(:writebook)).to_set
    assert_empty Card.where(board: new_board)
  end

  test "tagged with" do
    assert_equal cards(:layout, :text), Card.tagged_with(tags(:mobile))
  end

  test "for published cards, it should set the default title 'Untitiled' when not provided" do
    card = boards(:writebook).cards.create!
    assert_nil card.title

    card.publish
    assert_equal "Untitled", card.reload.title
  end

  test "send back to triage when moved to a new board" do
    cards(:logo).update! column: columns(:writebook_in_progress)

    assert_changes -> { cards(:logo).reload.triaged? }, from: true, to: false do
      cards(:logo).update! board: boards(:private)
    end
  end

  test "grants access to assignees when moved to a new board" do
    card = cards(:logo)
    assignee = users(:david)
    card.toggle_assignment(assignee)

    board = boards(:private)
    assert_not_includes board.users, assignee

    card.update!(board: board)
    assert_includes board.users.reload, assignee
  end

  test "move cards to a different board" do
    card = cards(:logo)
    old_board = boards(:writebook)
    new_board = boards(:private)

    assert_equal old_board, card.board

    assert card.events.where(board: old_board).exists?

    card.move_to(new_board)

    assert_equal new_board, card.reload.board

    events_in_old_board = card.events.where(board: old_board)
    events_in_new_board = card.events.where(board: new_board)

    assert_empty events_in_old_board
    assert events_in_new_board.exists?

    board_changed_event = events_in_new_board.find { |event| event.action == "card_board_changed" }
    assert board_changed_event
  end

  test "a card is filled if it has either the title or the description set" do
    assert Card.new(title: "Some title").filled?
    assert Card.new(description: "Some description").filled?

    assert_not Card.new.filled?
  end
end
