module OauthAuditTestHelper
  FIELDS = %i[ app event client_id client_class client_type grant_id family_id identity_id tenant_id actor reason request_id ]
  DETAILS = %i[ grant_type permission presented ]

  # A token or client secret carries its prefix, and a digest is 64 hex digits,
  # optionally versioned (TokenDigester).
  CREDENTIAL = /fizzy_(?:pat|at|rt|cs)_|\A(?:\d+\$)?\h{64}\z/

  class Recorder
    attr_reader :events

    def initialize
      @events = []
    end

    def emit(event)
      @events << event
    end
  end

  # The OAuth audit events reported while the block runs. Each is checked to
  # carry exactly the standard fields, none of them masked by the payload
  # filter, and nothing shaped like a token or digest.
  def capture_oauth_events
    recorder = Recorder.new
    Rails.event.subscribe(recorder) { |event| event[:name].start_with?("oauth.") }
    yield
    recorder.events.each { |event| assert_well_formed_oauth_event event }
    recorder.events
  ensure
    Rails.event.unsubscribe(recorder)
  end

  def oauth_event_names(events)
    events.map { |event| event[:name] }
  end

  def oauth_event(events, name)
    matching = events.select { |event| event[:name] == name }
    assert_equal 1, matching.size, "expected one #{name} among #{oauth_event_names(events)}"
    matching.first[:payload]
  end

  # No payload value is, or contains, any of the given secrets.
  def assert_no_secrets_in(events, *secrets)
    secrets = secrets.compact.flat_map { |secret| [ secret, TokenDigester.digest(secret) ] }
    assert secrets.any?, "no secrets to look for"

    events.each do |event|
      event[:payload].each do |field, value|
        secrets.each { |secret| assert_not_includes value.to_s, secret, "#{event[:name]} #{field} carries a secret" }
      end
    end
  end

  private
    def assert_well_formed_oauth_event(event)
      payload = event[:payload]

      assert_equal event[:name], payload[:event]
      assert_equal "fizzy", payload[:app]
      assert_empty FIELDS - payload.keys, "#{event[:name]} lacks standard fields"
      assert_empty payload.keys - FIELDS - DETAILS, "#{event[:name]} carries unexpected fields"
      assert_includes Oauth::Audit::ACTORS, payload[:actor]

      payload.each do |field, value|
        assert_no_match CREDENTIAL, value.to_s, "#{event[:name]} #{field} looks like a credential"
        assert_not_equal "[FILTERED]", value, "#{event[:name]} #{field} was masked by filter_parameters"
      end
    end
end
