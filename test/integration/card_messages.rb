require "test_helper"

class BubbleMessagesTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "messages system" do
    # Create a bubble
    post bucket_bubbles_url(buckets(:writebook))
    bubble = Bubble.last
    assert_equal 1, bubble.messages.count
    assert_predicate bubble.messages.last, :event_summary?
    assert_equal "created", bubble.messages.last.messageable.events.sole.action

    # Boost it
    post bubble_boosts_path(bubble, format: :turbo_stream)
    assert_equal 1, bubble.messages.count
    assert_predicate bubble.messages.last, :event_summary?
    assert_equal 2, bubble.messages.last.event_summary.events.count
    assert_equal "boosted", bubble.messages.last.messageable.events.last.action

    # Comment on it
    post bucket_bubble_comments_url(buckets(:writebook), bubble), params: { comment: { body: "Agreed." } }
    assert_equal 2, bubble.messages.count
    assert_predicate bubble.messages.last, :comment?
    assert_equal "Agreed.", bubble.messages.last.messageable.body

    # Assign it
    post bucket_bubble_assignments_url(buckets(:writebook), bubble), params: { assignee_id: users(:kevin).id }
    assert_equal 3, bubble.messages.count
    assert_predicate bubble.messages.last, :event_summary?
    assert_equal 1, bubble.messages.last.event_summary.events.count
    assert_equal "assigned", bubble.messages.last.messageable.events.last.action

    # Stage it
    post bubble_stagings_url(bubble), params: { stage_id: workflow_stages(:qa_triage).id }
    assert_equal 3, bubble.messages.count
    assert_predicate bubble.messages.last, :event_summary?
    assert_equal 2, bubble.messages.last.event_summary.events.count
    assert_equal "staged", bubble.messages.last.messageable.events.last.action

    # Unstage it
    post bubble_stagings_url(bubble), params: { stage_id: workflow_stages(:qa_triage).id }
    assert_equal 3, bubble.messages.count
    assert_predicate bubble.messages.last, :event_summary?
    assert_equal 3, bubble.messages.last.event_summary.events.count
    assert_equal "unstaged", bubble.messages.last.messageable.events.last.action
  end
end
