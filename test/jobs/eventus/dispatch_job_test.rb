# frozen_string_literal: true

require "test_helper"

class Eventus::DispatchJobTest < ActiveJob::TestCase
  setup do
    @card = cards(:logo)
    @bot = users(:agora_bot)
    @assigner = users(:david)
    @event_url = "http://eventus-test:3000"
    @endpoint = "#{@event_url}/events/fizzy/realtime"
  end

  test "does nothing when EVENTUS_REALTIME_URL is not set" do
    event = build_assigned_event(assignee_ids: [ @bot.id ])

    stub_request(:post, @endpoint).to_raise("should not be called")

    with_env("EVENTUS_REALTIME_URL" => nil) do
      assert_nothing_raised { Eventus::DispatchJob.perform_now(event) }
    end

    assert_not_requested :post, @endpoint
  end

  test "does nothing when action is not card_assigned" do
    event = events(:logo_published)

    with_env("EVENTUS_REALTIME_URL" => @event_url) do
      assert_nothing_raised { Eventus::DispatchJob.perform_now(event) }
    end

    assert_not_requested :post, @endpoint
  end

  test "does nothing when no bot user is assigned" do
    event = events(:logo_assignment_jz) # jz is a regular member

    with_env("EVENTUS_REALTIME_URL" => @event_url) do
      assert_nothing_raised { Eventus::DispatchJob.perform_now(event) }
    end

    assert_not_requested :post, @endpoint
  end

  test "posts to Eventus realtime endpoint when bot user is assigned" do
    event = create_card_assigned_event(assignee: @bot)

    stub = stub_request(:post, @endpoint)
      .with(
        headers: { "Content-Type" => "application/json" },
        body: hash_including(
          "event_type" => "ticket.assigned",
          "ticket" => hash_including(
            "id" => @card.id,
            "assignee" => hash_including("id" => @bot.id, "type" => "bot")
          )
        )
      )
      .to_return(status: 200, body: { id: 1, status: "processed" }.to_json)

    with_env("EVENTUS_REALTIME_URL" => @event_url) do
      Eventus::DispatchJob.perform_now(event)
    end

    assert_requested stub
  end

  test "includes triggered_by in payload" do
    event = create_card_assigned_event(assignee: @bot)

    stub = stub_request(:post, @endpoint)
      .with(body: hash_including("triggered_by" => hash_including("name" => @assigner.name, "type" => "user")))
      .to_return(status: 200, body: "{}")

    with_env("EVENTUS_REALTIME_URL" => @event_url) do
      Eventus::DispatchJob.perform_now(event)
    end

    assert_requested stub
  end

  private

  def create_card_assigned_event(assignee:)
    Event.create!(
      action: "card_assigned",
      board: @card.board,
      creator: @assigner,
      eventable: @card,
      account: @card.account,
      particulars: { assignee_ids: [ assignee.id ] }
    )
  end

  def build_assigned_event(assignee_ids:)
    event = Event.new(
      action: "card_assigned",
      board: @card.board,
      creator: @assigner,
      eventable: @card,
      account: @card.account,
      particulars: { assignee_ids: assignee_ids }
    )
    event.id = SecureRandom.uuid
    event
  end

  def with_env(vars)
    keys = vars.keys.map(&:to_s)
    saved = keys.index_with { |k| ENV[k] }
    vars.each { |k, v| v.nil? ? ENV.delete(k.to_s) : ENV[k.to_s] = v.to_s }
    yield
  ensure
    keys.each { |k| saved[k].nil? ? ENV.delete(k) : ENV[k] = saved[k] }
  end
end
