require "test_helper"

class Webhook::DeliveryTest < ActiveSupport::TestCase
  PUBLIC_TEST_IP = "93.184.216.34" # example.com's real IP, used as a public IP stand-in

  setup do
    stub_dns_resolution(PUBLIC_TEST_IP)
  end

  test "create" do
    webhook = webhooks(:active)
    event = events(:layout_commented)
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)

    assert_equal "pending", delivery.state
  end

  test "succeeded" do
    webhook = webhooks(:active)
    event = events(:layout_commented)
    delivery = Webhook::Delivery.new(
      webhook: webhook,
      event: event,
      response: { code: 200 },
      state: :completed
    )
    assert delivery.succeeded?

    delivery.response[:code] = 422
    assert_not delivery.succeeded?, "resonse must have a 2XX status"

    delivery.response[:code] = 200
    delivery.state = :pending
    assert_not delivery.succeeded?, "state must be completed"

    delivery.state = :in_progress
    assert_not delivery.succeeded?, "state must be completed"

    delivery.state = :errored
    assert_not delivery.succeeded?, "state must be completed"

    delivery.state = :completed
    delivery.response[:error] = :destination_unreachable

    assert_not delivery.succeeded?, "the response can't have an error"
  end

  test "deliver_later" do
    delivery = webhook_deliveries(:pending)

    assert_enqueued_with job: Webhook::DeliveryJob, args: [ delivery ] do
      delivery.deliver_later
    end
  end

  test "deliver" do
    delivery = webhook_deliveries(:pending)

    stub_request(:post, delivery.webhook.url)
      .to_return(status: 200, headers: { "content-type" => "application/json" })

    assert_equal "pending", delivery.state

    tracker = delivery.webhook.delinquency_tracker
    tracker.update!(consecutive_failures_count: 0)

    assert_no_difference -> { tracker.reload.consecutive_failures_count } do
      delivery.deliver
    end

    assert delivery.persisted?
    assert_equal "completed", delivery.state
    assert delivery.request[:headers].present?
    assert_equal 200, delivery.response[:code]
    assert delivery.response[:error].blank?
    assert delivery.succeeded?
  end

  test "deliver when the network timeouts" do
    delivery = webhook_deliveries(:pending)
    stub_request(:post, delivery.webhook.url).to_timeout

    tracker = delivery.webhook.delinquency_tracker
    assert_difference -> { tracker.reload.consecutive_failures_count }, 1 do
      delivery.deliver
    end

    assert_equal "completed", delivery.state
    assert_equal "connection_timeout", delivery.response[:error]
    assert_not delivery.succeeded?
  end

  test "deliver when the connection is refused" do
    delivery = webhook_deliveries(:pending)
    stub_request(:post, delivery.webhook.url).to_raise(Errno::ECONNREFUSED)

    delivery.deliver

    assert_equal "completed", delivery.state
    assert_equal "destination_unreachable", delivery.response[:error]
  end

  test "deliver when an SSL error occurs" do
    delivery = webhook_deliveries(:pending)
    stub_request(:post, delivery.webhook.url).to_raise(OpenSSL::SSL::SSLError)

    delivery.deliver

    assert_equal "completed", delivery.state
    assert_equal "failed_tls", delivery.response[:error]
  end

  test "deliver when an unexpected error occurs" do
    delivery = webhook_deliveries(:pending)
    stub_request(:post, delivery.webhook.url).to_raise(StandardError, "Unexpected error")

    assert_raises(StandardError) do
      delivery.deliver
    end

    assert_equal "errored", delivery.state
  end

  test "deliver with basecamp webhook format" do
    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Basecamp",
      url: "https://3.basecamp.com/123/integrations/webhook/buckets/456/chats/789/lines"
    )
    event = events(:layout_commented)
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)

    request_stub = stub_request(:post, webhook.url)
      .with do |request|
        body = CGI.parse(request.body)
        body.key?("content") && body["content"].first.present? &&
        request.headers["Content-Type"] == "application/x-www-form-urlencoded"
      end
      .to_return(status: 200)

    delivery.deliver

    assert_requested request_stub
    assert delivery.succeeded?
  end

  test "deliver with campfire webhook format" do
    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Campfire",
      url: "https://example.com/rooms/123/456-room-name/messages"
    )
    event = events(:layout_commented)
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)

    request_stub = stub_request(:post, webhook.url)
      .with do |request|
        request.body.is_a?(String) && !request.body.start_with?("{") && request.body.present? &&
        request.headers["Content-Type"] == "text/html"
      end
      .to_return(status: 200)

    delivery.deliver

    assert_requested request_stub
    assert delivery.succeeded?
  end

  test "deliver with slack webhook format" do
    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Slack",
      url: "https://hooks.slack.com/services/T12345678/B12345678/abcdefghijklmnopqrstuvwx" # gitleaks:allow
    )
    event = events(:layout_commented)
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)

    request_stub = stub_request(:post, webhook.url)
      .with do |request|
        body = JSON.parse(request.body)
        body.key?("text") && body["text"].present? &&
        request.headers["Content-Type"] == "application/json"
      end
      .to_return(status: 200)

    delivery.deliver

    assert_requested request_stub
    assert delivery.succeeded?
  end

  test "deliver with generic webhook format" do
    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Generic",
      url: "https://example.com/webhook"
    )
    event = events(:layout_commented)
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)

    request_stub = stub_request(:post, webhook.url)
      .with do |request|
        body = JSON.parse(request.body)
        body.present? && !body.key?("line") && !body.key?("text") &&
        request.headers["Content-Type"] == "application/json"
      end
      .to_return(status: 200)

    delivery.deliver

    assert_requested request_stub
    assert delivery.succeeded?
  end

  test "cleanup" do
    webhook = webhooks(:active)
    event = events(:layout_commented)

    fresh_delivery = Webhook::Delivery.create!(webhook: webhook, event: event)
    stale_delivery = Webhook::Delivery.create!(webhook: webhook, event: event, created_at: 8.days.ago)

    Webhook::Delivery.cleanup

    assert Webhook::Delivery.exists?(fresh_delivery.id)
    assert_not Webhook::Delivery.exists?(stale_delivery.id)
  end

  test "renders the creator name when event creator is current user" do
    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Basecamp",
      url: "https://3.basecamp.com/123/integrations/webhook/buckets/456/chats/789/lines"
    )
    event = events(:logo_published)
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)

    Current.session = sessions(:david)

    request_stub = stub_request(:post, webhook.url)
      .with { |request| CGI.parse(request.body)["content"].first.include?("David added") }
      .to_return(status: 200)

    delivery.deliver

    assert_requested request_stub
  end

  test "basecamp webhook payload html-escapes special characters" do
    cards(:logo).update_column(:title, %(Tom & Jerry's <Great> "Adventure"))

    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Basecamp",
      url: "https://3.basecamp.com/123/integrations/webhook/buckets/456/chats/789/lines"
    )
    delivery = Webhook::Delivery.create!(webhook: webhook, event: events(:logo_published))

    captured_body = nil
    stub_request(:post, webhook.url)
      .with { |request| captured_body = request.body; true }
      .to_return(status: 200)

    delivery.deliver

    content = CGI.parse(captured_body)["content"].first

    expected = <<~HTML.strip
      David added &quot;Tom &amp; Jerry&#39;s &lt;Great&gt; &quot;Adventure&quot;&quot;
      <a href="http://example.org/897362094/cards/1">↗︎</a>
    HTML
    assert_equal expected, content
  end

  test "slack webhook payload html-escapes special characters" do
    cards(:logo).update_column(:title, %(Tom & Jerry's <Great> "Adventure"))

    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Slack",
      url: "https://hooks.slack.com/services/T12345678/B12345678/abcdefghijklmnopqrstuvwx" # gitleaks:allow
    )
    delivery = Webhook::Delivery.create!(webhook: webhook, event: events(:logo_published))

    captured_body = nil
    stub_request(:post, webhook.url)
      .with { |request| captured_body = request.body; true }
      .to_return(status: 200)

    delivery.deliver

    text = JSON.parse(captured_body)["text"]

    expected = <<~TEXT.strip
      David added &quot;Tom &amp; Jerry&#39;s &lt;Great&gt; &quot;Adventure&quot;&quot; <http://example.com/897362094/cards/1|Open in Fizzy>
    TEXT
    assert_equal expected, text
  end

  test "campfire webhook payload html-escapes special characters" do
    cards(:logo).update_column(:title, %(Tom & Jerry's <Great> "Adventure"))

    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Campfire",
      url: "https://example.com/rooms/123/456-room-name/messages"
    )
    delivery = Webhook::Delivery.create!(webhook: webhook, event: events(:logo_published))

    captured_body = nil
    stub_request(:post, webhook.url)
      .with { |request| captured_body = request.body; true }
      .to_return(status: 200)

    delivery.deliver

    expected = <<~HTML.strip
      David added &quot;Tom &amp; Jerry&#39;s &lt;Great&gt; &quot;Adventure&quot;&quot;
      <a href="http://example.org/897362094/cards/1">↗︎</a>
    HTML
    assert_equal expected, captured_body
  end

  test "generic webhook payload json-encodes special characters" do
    cards(:logo).update_column(:title, %(Tom & Jerry's <Great> "Adventure"))

    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Generic",
      url: "https://example.com/webhook"
    )
    delivery = Webhook::Delivery.create!(webhook: webhook, event: events(:logo_published))

    captured_body = nil
    stub_request(:post, webhook.url)
      .with { |request| captured_body = request.body; true }
      .to_return(status: 200)

    delivery.deliver

    json = JSON.parse(captured_body)
    assert_equal %(Tom & Jerry's <Great> "Adventure"), json["eventable"]["title"]
  end

  test "renders creator name when event creator is not current user" do
    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Basecamp",
      url: "https://3.basecamp.com/123/integrations/webhook/buckets/456/chats/789/lines"
    )
    event = events(:logo_published)
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)

    Current.session = sessions(:kevin)

    request_stub = stub_request(:post, webhook.url)
      .with { |request| CGI.parse(request.body)["content"].first.include?("David added") }
      .to_return(status: 200)

    delivery.deliver

    assert_requested request_stub
  end

  test "blocks DNS rebinding attack where hostname resolves to private IP after validation" do
    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Rebind Attack",
      url: "https://rebind.attacker.example/webhook"
    )
    event = events(:layout_commented)
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)

    # Stub DNS to return a private IP (simulating rebind to internal host)
    stub_dns_resolution("169.254.169.254") # AWS IMDS link-local address

    delivery.deliver

    assert_equal "completed", delivery.state
    assert_equal "private_uri", delivery.response[:error]
    assert_not delivery.succeeded?
  end

  test "connects to the pinned IP address preventing DNS re-resolution" do
    webhook = Webhook.create!(
      board: boards(:writebook),
      name: "Pinned IP",
      url: "https://example.com/webhook"
    )
    event = events(:layout_commented)
    delivery = Webhook::Delivery.create!(webhook: webhook, event: event)

    stub_dns_resolution(PUBLIC_TEST_IP)

    # Verify Net::HTTP.new is called with the pinned IP
    response_mock = stub(code: "200")
    response_mock.stubs(:read_body)

    http_mock = mock("http")
    http_mock.stubs(:use_ssl=)
    http_mock.stubs(:ipaddr=)
    http_mock.stubs(:open_timeout=)
    http_mock.stubs(:read_timeout=)
    http_mock.stubs(:request).yields(response_mock).returns(response_mock)

    Net::HTTP.expects(:new).with("example.com", 443).returns(http_mock)

    delivery.deliver

    assert delivery.succeeded?
  end

  test "handles response too large error" do
    delivery = webhook_deliveries(:pending)

    large_body = "x" * 200.kilobytes
    stub_request(:post, delivery.webhook.url).to_return(status: 200, body: large_body)

    delivery.deliver

    assert_equal "completed", delivery.state
    assert_equal "response_too_large", delivery.response[:error]
    assert_not delivery.succeeded?
  end

  test "allows responses within size limit" do
    delivery = webhook_deliveries(:pending)

    small_body = "x" * 50.kilobytes
    stub_request(:post, delivery.webhook.url).to_return(status: 200, body: small_body)

    delivery.deliver

    assert_equal "completed", delivery.state
    assert_equal 200, delivery.response[:code]
    assert delivery.succeeded?
  end

  private
    def stub_dns_resolution(*ips)
      dns_mock = mock("dns")
      dns_mock.stubs(:each_address).multiple_yields(*ips)
      Resolv::DNS.stubs(:open).yields(dns_mock)
    end
end
