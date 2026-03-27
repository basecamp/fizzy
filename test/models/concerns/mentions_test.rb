require "test_helper"

class MentionsTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "don't create mentions when creating or updating drafts" do
    assert_no_difference -> { Mention.count } do
      perform_enqueued_jobs only: Mention::CreateJob do
        card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(users(:david))}?"
        card.update description: "Any thoughts here #{mention_html_for(users(:jz))}"
      end
    end
  end

  test "create mentions from plain text mentions when publishing cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = assert_no_difference -> { Mention.count } do
        boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(users(:david))}?"
      end

      card = Card.find(card.id)

      assert_difference -> { Mention.count }, +1 do
        card.publish
      end
    end
  end

  test "create mentions from rich text mentions when publishing cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = assert_no_difference -> { Mention.count } do
        boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(users(:david))}?"
      end

      card = Card.find(card.id)

      assert_difference -> { Mention.count }, +1 do
        card.published!
      end
    end
  end

  test "don't create repeated mentions when updating cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(users(:david))}?"

      assert_difference -> { Mention.count }, +1 do
        card.published!
      end

      assert_no_difference -> { Mention.count } do
        card.update description: "Any thoughts here #{mention_html_for(users(:david))}"
      end

      assert_difference -> { Mention.count }, +1 do
        card.update description: "Any thoughts here #{mention_html_for(users(:jz))}"
      end
    end
  end

  test "create mentions from plain text mentions when posting comments" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Some initial content", status: :published

      assert_difference -> { Mention.count }, +1 do
        card.comments.create!(body: "Great work on this #{mention_html_for(users(:david))}!")
      end
    end
  end

  test "can't mention users that don't have access to the board" do
    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from(users(:david))

    assert_no_difference -> { Mention.count }, +1 do
      perform_enqueued_jobs only: Mention::CreateJob do
        boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(users(:david))}?"
      end
    end
  end

  test "notify new mentionees when editing a comment to add a mention" do
    card = boards(:writebook).cards.create title: "Fresh card", description: "Some content", status: :published

    perform_enqueued_jobs do
      comment = card.comments.create!(body: "Initial thought")

      assert_difference -> { users(:kevin).notifications.count }, +1 do
        comment.update!(body: "Actually, #{mention_html_for(users(:kevin))}, what do you think?")
      end
    end
  end

  test "mentionees are added as watchers of the card" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup #{mention_html_for(users(:kevin))}?"
      card.published!
      assert card.watchers.include?(users(:kevin))
    end
  end

  private
    def mention_html_for(user)
      ActionText::Attachment.from_attachable(user).to_html
    end
end
