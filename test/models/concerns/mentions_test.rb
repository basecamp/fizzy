require "test_helper"

class MentionsTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "don't create mentions when creating or updating drafts" do
    assert_no_difference -> { Mention.count } do
      perform_enqueued_jobs only: Mention::CreateJob do
        card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, @david?"
        card.update description: "Any thoughts here @jz"
      end
    end
  end

  test "create mentions from plain text mentions when publishing cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = assert_no_difference -> { Mention.count } do
        boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, @david?"
      end

      card = Card.find(card.id)

      assert_difference -> { Mention.count }, +1 do
        card.published!
      end
    end
  end

  test "create mentions from rich text mentions when publishing cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = assert_no_difference -> { Mention.count } do
        attachment = ActionText::Attachment.from_attachable(users(:david))
        boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{attachment.to_html}?"
      end

      card = Card.find(card.id)

      assert_difference -> { Mention.count }, +1 do
        card.published!
      end
    end
  end

  test "don't create repeated mentions when updating cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, @david?"

      assert_difference -> { Mention.count }, +1 do
        card.published!
      end

      assert_no_difference -> { Mention.count } do
        card.update description: "Any thoughts here @david"
      end

      assert_difference -> { Mention.count }, +1 do
        card.update description: "Any thoughts here @jz"
      end
    end
  end

  test "create mentions from plain text mentions when posting comments" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Some initial content", status: :published

      assert_difference -> { Mention.count }, +1 do
        card.comments.create!(body: "Great work on this @david!")
      end
    end
  end

  test "don't create mentions from comments when belonging to unpublished cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Some initial content"

      assert_no_difference -> { Mention.count } do
        card.comments.create!(body: "Great work on this @david!")
      end
    end
  end

  test "can't mention users that don't have access to the board" do
    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from(users(:david))

    assert_no_difference -> { Mention.count }, +1 do
      perform_enqueued_jobs only: Mention::CreateJob do
        attachment = ActionText::Attachment.from_attachable(users(:david))
        boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{attachment.to_html}?"
      end
    end
  end

  test "mentionees are added as watchers of the card" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup @kevin?"
      card.published!
      assert card.watchers.include?(users(:kevin))
    end
  end
end
