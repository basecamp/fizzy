require "test_helper"

class ReactionTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "creating a comment reaction touches the card activity" do
    assert_changes -> { cards(:logo).reload.last_active_at } do
      comments(:logo_1).reactions.create!(content: "Nice!")
    end
  end

  test "reactions are deleted when comment is destroyed" do
    comment = comments(:logo_1)
    comment.reactions.create!(content: "👍")
    reaction_ids = comment.reactions.pluck(:id)

    assert reaction_ids.any?, "Expected comment to have reactions"

    comment.destroy

    assert_empty Reaction.where(id: reaction_ids)
  end

  test "creating a card reaction touches the card activity" do
    card = cards(:logo)

    assert_changes -> { card.reload.last_active_at } do
      card.reactions.create!(content: "🎉")
    end
  end

  test "reactions are deleted when card is destroyed" do
    card = cards(:logo)
    reaction_ids = card.reactions.pluck(:id)

    assert reaction_ids.any?, "Expected card to have reactions"

    card.destroy

    assert_empty Reaction.where(id: reaction_ids)
  end
end
