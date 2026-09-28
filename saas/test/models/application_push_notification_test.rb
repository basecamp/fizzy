require "test_helper"

class ApplicationPushNotificationTest < ActiveSupport::TestCase
  CONFIGURED = {
    apple: { key_id: "ABC123DEF4", encryption_key: "p8-key-material" },
    google: { encryption_key: "{\"type\":\"service_account\"}" }
  }.freeze

  setup do
    # Autoload the class under the real test env before any test stubs
    # Rails.env, or the class body's boot-time guard fires mid-stub.
    ApplicationPushNotification
  end

  test "disabled in test" do
    assert_not ApplicationPushNotification.enabled
  end

  test "disabled on staging, where push credentials are deliberately unprovisioned" do
    with_rails_env "staging" do
      assert_not ApplicationPushNotification.enable?
    end
  end

  test "disabled in development by default" do
    with_rails_env "development" do
      assert_not ApplicationPushNotification.enable?
    end
  end

  test "enabled on production" do
    with_rails_env "production" do
      assert ApplicationPushNotification.enable?
    end
  end

  test "enabled on beta" do
    with_rails_env "beta" do
      assert ApplicationPushNotification.enable?
    end
  end

  test "ENABLE_NATIVE_PUSH=true enables push in otherwise-disabled environments" do
    with_env "ENABLE_NATIVE_PUSH" => "true" do
      with_rails_env "staging" do
        assert ApplicationPushNotification.enable?
      end
    end
  end

  test "verify_credentials! passes when all credentials are present" do
    ActionPushNative.stubs(:config).returns(CONFIGURED)

    assert_nothing_raised do
      ApplicationPushNotification.verify_credentials!
    end
  end

  test "verify_credentials! names each missing credential" do
    { "APNS_KEY_ID" => [ :apple, :key_id ],
      "APNS_ENCRYPTION_KEY_B64" => [ :apple, :encryption_key ],
      "FCM_ENCRYPTION_KEY_B64" => [ :google, :encryption_key ] }.each do |env_var, (platform, key)|
      config = { apple: CONFIGURED[:apple].dup, google: CONFIGURED[:google].dup }
      config[platform][key] = ""
      ActionPushNative.stubs(:config).returns(config)

      error = assert_raises RuntimeError do
        ApplicationPushNotification.verify_credentials!
      end
      assert_equal "Native push is enabled but #{env_var} is not set", error.message
    end
  end

  private
    def with_rails_env(env)
      Rails.stubs(:env).returns(ActiveSupport::EnvironmentInquirer.new(env))
      yield
    ensure
      Rails.unstub(:env)
    end

    def with_env(vars)
      originals = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| ENV[key] = value }
      yield
    ensure
      originals.each { |key, value| ENV[key] = value }
    end
end
