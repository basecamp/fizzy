require "test_helper"

# What reaches Loki: the structured log line rails_structured_logging writes for each request and job, with
# the request's or job's log (SQL included, Rails.event being in debug mode) in its `original` field.
class Fizzy::Saas::StructuredLogRedactionTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # Made-up values, distinctive enough that finding one in a log can only mean it leaked.
  CODE = "ZQ7XW3"
  TOKEN = "madeUpAccessToken0000000"
  JOIN_CODE_PART = "Zfake3Join4C"
  WEBHOOK_URL = "https://hooks.slack.com/services/T0000/B0000/madeUpWebhookPath0000"

  test "signing in with a magic link logs no code, from the mail's delivery to its redemption" do
    MagicLink::Code.stubs(:generate).returns(CODE)
    identity = identities(:kevin)

    lines = structured_log_lines do
      untenanted do
        perform_enqueued_jobs do
          post session_path, params: { email_address: identity.email_address }
        end
        post session_magic_link_url, params: { code: CODE }
      end
    end

    assert cookies[:session_token].present?, "the code should still sign in"
    assert lines.any? { |line| line.include?("INSERT INTO `magic_links`") }
    assert lines.any? { |line| line.include?("FROM `magic_links`") }
    assert lines.any? { |line| line.include?("Delivered mail") }
    assert lines.any? { |line| line.include?("Sessions::MagicLinksController") }
    assert_no_secret CODE, lines
  end

  test "an API request logs no bearer token" do
    identities(:jason).access_tokens.create!(token: TOKEN, permission: "read")

    lines = structured_log_lines do
      get user_path(users(:jason), script_name: accounts("37s").slug), env: { "HTTP_AUTHORIZATION" => "Bearer #{TOKEN}" }, as: :json
    end

    assert_response :success
    assert lines.any? { |line| line.include?("FROM `identity_access_tokens`") }
    assert_no_secret TOKEN, lines
  end

  test "resetting a join code logs no code" do
    sign_in_as :kevin
    SecureRandom.stubs(:base58).with(Account::JoinCode::CODE_LENGTH).returns(JOIN_CODE_PART)

    lines = structured_log_lines { delete account_join_code_path }

    assert_redirected_to account_join_code_path
    assert_equal "Zfak-e3Jo-in4C", Current.account.join_code.reload.code
    assert lines.any? { |line| line.include?("UPDATE `account_join_codes`") }
    assert_no_secret "Zfak-e3Jo-in4C", lines
  end

  test "creating a webhook logs neither its URL nor its signing secret" do
    # Production eager loads, and the encrypted attributes that loads add dotted parameter filters, which
    # change how every filter is matched.
    Rails.application.eager_load!
    sign_in_as :kevin

    lines = structured_log_lines do
      post board_webhooks_path(boards(:writebook)), params: { webhook: { name: "Made up", url: WEBHOOK_URL, subscribed_actions: [ "card_published" ] } }
    end

    webhook = Webhook.find_by!(url: WEBHOOK_URL)
    assert_redirected_to board_webhook_path(webhook.board, webhook)
    assert lines.any? { |line| line.include?("INSERT INTO `webhooks`") }
    assert_no_secret WEBHOOK_URL, lines
    assert_no_secret webhook.signing_secret, lines
  end

  class DuplicateMagicLinkJob < ApplicationJob
    def perform(identity)
      identity.magic_links.new(code: CODE, expires_at: 1.minute.from_now).save!(validate: false)
    end
  end

  test "a database error on a redacted table reaches the job's log line without the value" do
    identities(:kevin).magic_links.create!(code: CODE)

    lines = structured_log_lines do
      assert_raises ActiveRecord::RecordNotUnique do
        DuplicateMagicLinkJob.perform_now(identities(:kevin))
      end
    end

    assert lines.any? { |line| line.include?("RecordNotUnique") && line.include?(ActiveRecordSqlRedaction::FILTERED_ERROR) }
    assert_no_secret CODE, lines
  end

  test "Sentry's breadcrumbs and DB spans get the redacted SQL from the notification itself" do
    with_sentry(filters: false) do
      transaction = Sentry.start_transaction(op: "test", name: "redaction")
      Sentry.get_current_scope.set_span(transaction)
      identities(:kevin).magic_links.create!(code: CODE)
      # The repeat lookup is a query-cache hit, which is what becomes a DB span (see with_sentry).
      ActiveRecord::Base.cache { 2.times { assert MagicLink.find_by(code: CODE) } }
      transaction.finish

      breadcrumbs = Sentry.get_current_scope.breadcrumbs.members.select { |crumb| crumb.category == "sql.active_record" && crumb.data[:sql].to_s.include?("magic_links") }
      spans = sentry_events.flat_map { |event| event.try(:spans) || [] }.select { |span| span[:op].to_s.start_with?("db") && span[:description].to_s.include?("magic_links") }

      assert breadcrumbs.many?, "Sentry should record SQL breadcrumbs"
      assert spans.any?, "Sentry should record a DB span"
      assert_no_secret CODE, breadcrumbs.map { |crumb| crumb.data[:sql] } + spans.map { |span| span[:description] }
    end
  end

  test "Sentry configured as in production records no value in breadcrumbs, spans or errors" do
    with_sentry(filters: true) do
      identities(:kevin).magic_links.create!(code: CODE)
      transaction = Sentry.start_transaction(op: "test", name: "redaction")
      Sentry.get_current_scope.set_span(transaction)
      ActiveRecord::Base.cache { 2.times { assert MagicLink.find_by(code: CODE) } }
      assert_raises(ActiveRecord::RecordNotUnique) { identities(:kevin).magic_links.new(code: CODE, expires_at: 1.minute.from_now).save!(validate: false) }
      transaction.finish
      Sentry.capture_exception(ActiveRecord::RecordNotUnique.new("Trilogy::ProtocolError: 1062: Duplicate entry '#{CODE}' for key 'magic_links.index_magic_links_on_code'"))

      assert sentry_events.many?
      assert_no_secret CODE, sentry_events.map { |event| event.to_h.to_json }
      assert_no_secret CODE, Sentry.get_current_scope.breadcrumbs.members.map { |crumb| crumb.data.to_json }
    end
  end

  # The callbacks are a backstop for SQL that reaches Sentry outside the notification, so they're tested
  # directly, on SQL the notification never redacted.
  test "Sentry's backstop callbacks redact breadcrumbs, errors and spans" do
    config = Sentry::Configuration.new
    Fizzy::Saas::SentrySqlRedaction.install(config)
    sql = "SELECT `magic_links`.* FROM `magic_links` WHERE `magic_links`.`code` = '#{CODE}' LIMIT 1"

    breadcrumb = Sentry::Breadcrumb.new(category: "sql.active_record", data: { sql: sql })
    assert_no_secret CODE, [ config.before_breadcrumb.call(breadcrumb, {}).data[:sql] ]

    unclosed = Sentry::Breadcrumb.new(category: "sql.active_record", data: { sql: "SELECT * FROM magic_links WHERE purpose = '0' AND code = '#{CODE}" })
    assert_no_secret CODE, [ config.before_breadcrumb.call(unclosed, {}).data[:sql] ]

    error = ActiveRecord::RecordNotUnique.new("Trilogy::ProtocolError: 1062: Duplicate entry '#{CODE}' for key 'magic_links.index_magic_links_on_code'")
    event = Sentry::ErrorEvent.new(configuration: config).tap { |event| event.add_exception_interface(error, mechanism: Sentry::Mechanism.new) }
    assert_no_secret CODE, [ config.before_send.call(event, {}).exception.values.map(&:value).inspect ]

    transaction = Struct.new(:spans).new([ { op: "db.sql.active_record", description: sql } ])
    assert_no_secret CODE, [ config.before_send_transaction.call(transaction, {}).spans.first[:description] ]
  end

  test "Sentry reports a join link's URL, Referer and transaction without its code" do
    config = Sentry::Configuration.new
    Fizzy::Saas::SentrySqlRedaction.install(config)

    event = Sentry::ErrorEvent.new(configuration: config)
    event.rack_env = Rack::MockRequest.env_for("https://app.fizzy.do/1234567/join/#{CODE}", "HTTP_REFERER" => "https://app.fizzy.do/public/boards/#{CODE}")
    event.transaction = "/1234567/join/#{CODE}"
    event = config.before_send.call(event, {})

    assert_equal "https://app.fizzy.do/1234567/join/[FILTERED]", event.request.url
    assert_equal "https://app.fizzy.do/public/boards/[FILTERED]", event.request.headers["Referer"]
    assert_equal "/1234567/join/[FILTERED]", event.transaction
  end

  test "opening a join link logs no code in its path" do
    code = accounts("37s").join_code.code

    lines = structured_log_lines { get join_path(code, script_name: accounts("37s").slug) }

    assert lines.any? { |line| JSON.parse(line).dig("url", "path").to_s.end_with?("/join/[FILTERED]") }
    assert_no_secret code, lines
  end

  test "Sentry breadcrumbs for other tables keep their SQL" do
    config = Sentry::Configuration.new
    Fizzy::Saas::SentrySqlRedaction.install(config)
    sql = "SELECT `cards`.* FROM `cards` WHERE `cards`.`title` = 'Made up' LIMIT 1"

    breadcrumb = Sentry::Breadcrumb.new(category: "sql.active_record", data: { sql: sql })
    assert_equal sql, config.before_breadcrumb.call(breadcrumb, {}).data[:sql]
  end

  private
    # Sentry as the engine starts it, delivering to a dummy transport, with tracing on so DB spans are
    # recorded. Everything it subscribes is removed afterwards by object; Sentry's own teardown unsubscribes
    # tracing by event name, which would take the redaction subscriber with it. On this Rails, executed
    # statements are instrumented through a handle that skips the timestamp Sentry's span recorder needs,
    # so only query-cache hits become DB spans.
    def with_sentry(filters:)
      notifier = ActiveSupport::Notifications.notifier
      traced = Sentry::Rails::Configuration.new.tracing_subscribers.flat_map { |subscriber| subscriber::EVENT_NAMES }
      before = traced.index_with { |name| notifier.listeners_for(name) }

      Sentry.init do |config|
        config.dsn = "http://public@sentry.example.invalid/1"
        config.transport.transport_class = Sentry::DummyTransport
        config.background_worker_threads = 0
        config.breadcrumbs_logger = [ :active_support_logger ]
        config.traces_sample_rate = 1.0
        Fizzy::Saas::SentrySqlRedaction.install(config) if filters
      end
      Sentry::Railtie.instance.send(:inject_breadcrumbs_logger)
      Sentry::Railtie.instance.send(:activate_tracing)

      assert_same ActiveRecordSqlRedaction::SUBSCRIBER, notifier.listeners_for("sql.active_record").first, "the redaction should still run first"
      yield
    ensure
      before&.each { |name, listeners| (notifier.listeners_for(name) - listeners).each { |subscriber| ActiveSupport::Notifications.unsubscribe(subscriber) } }
      Sentry::Rails::Breadcrumb::ActiveSupportLogger.detach if defined?(Sentry::Rails::Breadcrumb::ActiveSupportLogger)
      Sentry::Rails::Tracing.instance_variable_set(:@subscribed, false)
      Sentry::Rails::Tracing.subscribed_tracing_events.clear
      Sentry::Rails::Tracing.remove_active_support_notifications_patch
      Sentry.close if Sentry.initialized?
    end

    def sentry_events
      Sentry.get_current_client.transport.events
    end

    # The structured logger the subscribers were built with at boot, so this is the line they would write.
    def structured_log_lines
      lines = []
      Rails.application.config.structured_logging.logger.stubs(:info).with { |line| lines << line }
      yield
      lines
    end

    def assert_no_secret(secret, lines)
      assert lines.any?, "expected structured log lines"
      lines.each { |line| assert_not_includes line, secret }
    end
end
