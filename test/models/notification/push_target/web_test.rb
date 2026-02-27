require "test_helper"

class Notification::PushTarget::WebTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @notification = notifications(:logo_mentioned_david)

    @user.push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    @web_push_pool = mock("web_push_pool")
    Rails.configuration.x.stubs(:web_push_pool).returns(@web_push_pool)
  end

  test "pushes to web when user has subscriptions" do
    @web_push_pool.expects(:queue).once.with do |payload, subscriptions|
      payload.is_a?(Hash) &&
        payload[:title].present? &&
        payload[:body].present? &&
        payload[:url].present? &&
        subscriptions.count == 1
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "does not push when user has no subscriptions" do
    @user.push_subscriptions.delete_all
    @web_push_pool.expects(:queue).never

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload includes card title for card events" do
    @notification.update!(source: events(:logo_published))

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:title] == @notification.card.title
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for comment includes RE prefix" do
    event = events(:layout_commented)
    notification = @user.notifications.create!(source: event, creator: event.creator)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:title].start_with?("RE:")
    end

    Notification::PushTarget::Web.new(notification).process
  end

  test "payload for assignment includes assigned message" do
    @notification.update!(source: events(:logo_assignment_david))

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body].include?("Assigned to you")
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for triage includes column name" do
    event = events(:logo_published)
    event.update!(action: "card_triaged", particulars: { "particulars" => { "column" => "In Progress" } })
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved to In Progress by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for triage falls back when column name is missing" do
    event = events(:logo_published)
    event.update!(action: "card_triaged", particulars: {})
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for triage falls back when column name is blank" do
    event = events(:logo_published)
    event.update!(action: "card_triaged", particulars: { "particulars" => { "column" => "" } })
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for sent back to triage includes Maybe?" do
    event = events(:logo_published)
    event.update!(action: "card_sent_back_to_triage")
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved back to Maybe? by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for board change includes new board name" do
    event = events(:logo_published)
    event.update!(
      action: "card_board_changed",
      particulars: { "particulars" => { "old_board" => "Old Board", "new_board" => "New Board" } }
    )
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved to New Board by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for board change falls back when board name is missing" do
    event = events(:logo_published)
    event.update!(action: "card_board_changed", particulars: {})
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for board change falls back when board name is blank" do
    event = events(:logo_published)
    event.update!(
      action: "card_board_changed",
      particulars: { "particulars" => { "new_board" => "" } }
    )
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for collection change includes new collection name" do
    event = events(:logo_published)
    event.update!(
      action: "card_collection_changed",
      particulars: { "particulars" => { "new_collection" => "New Collection" } }
    )
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved to New Collection by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for collection change falls back when collection name is missing" do
    event = events(:logo_published)
    event.update!(action: "card_collection_changed", particulars: {})
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for collection change falls back when collection name is blank" do
    event = events(:logo_published)
    event.update!(action: "card_collection_changed", particulars: { "particulars" => { "new_collection" => "" } })
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for title change includes new title" do
    event = events(:logo_published)
    event.update!(
      action: "card_title_changed",
      particulars: { "particulars" => { "old_title" => "Old Title", "new_title" => "New Title" } }
    )
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Renamed to New Title by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for title change falls back when title is missing" do
    event = events(:logo_published)
    event.update!(action: "card_title_changed", particulars: {})
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Renamed by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for title change falls back when title is blank" do
    event = events(:logo_published)
    event.update!(action: "card_title_changed", particulars: { "particulars" => { "new_title" => "" } })
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Renamed by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for postponed includes Not Now" do
    event = events(:logo_published)
    event.update!(action: "card_postponed")
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved to Not Now by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for auto postponed includes inactivity message" do
    event = events(:logo_published)
    event.update!(action: "card_auto_postponed")
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Moved to Not Now due to inactivity"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for unhandled action uses updated fallback message" do
    event = events(:logo_published)
    event.update!(action: "card_unassigned")
    @notification.update!(source: event)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body] == "Updated by #{event.creator.name}"
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for mention includes mentioner name" do
    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:title].include?("mentioned you")
    end

    Notification::PushTarget::Web.new(@notification).process
  end
end
