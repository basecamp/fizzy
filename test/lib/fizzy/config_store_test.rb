require "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../../../cli/lib/fizzy/config_store"

class FizzyConfigStoreTest < ActiveSupport::TestCase
  private
    def with_env(overrides)
      original = {}
      overrides.each do |key, value|
        original[key] = ENV[key]
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
      yield
    ensure
      original.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end

  public
  test "save_profile persists profiles and current selection" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "config.yml")
      store = Fizzy::ConfigStore.new(path:)

      store.save_profile("agent", { "base_url" => "https://app.example.test", "token" => "secret" })

      assert_equal "agent", store.current_profile_name
      assert_equal "https://app.example.test", store.profile("agent")["base_url"]
      assert_equal "secret", store.profiles["agent"]["token"]
      assert_equal 0o600, File.stat(path).mode & 0o777
    end
  end

  test "set_current_profile switches to another saved profile" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "config.yml")
      store = Fizzy::ConfigStore.new(path:)

      store.save_profile("one", { "base_url" => "https://one.example.test" })
      store.save_profile("two", { "base_url" => "https://two.example.test" }, set_current: false)

      store.set_current_profile("two")

      assert_equal "two", store.current_profile_name
    end
  end

  test "current_profile_name prefers environment override" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "config.yml")
      store = Fizzy::ConfigStore.new(path:)
      store.save_profile("saved", { "base_url" => "https://saved.example.test" })

      with_env("FIZZY_PROFILE" => "env-profile") do
        assert_equal "env-profile", store.current_profile_name
      end
    end
  end

  test "standalone config_store raises Fizzy::Error without requiring client first" do
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      "-e",
      <<~RUBY,
        require_relative "cli/lib/fizzy/config_store"

        begin
          Fizzy::ConfigStore.new(path: "tmp/fizzy-config.yml").set_current_profile("missing")
        rescue => error
          puts error.class.name
          puts error.message
        end
      RUBY
      chdir: Rails.root.to_s
    )

    assert status.success?, stderr
    lines = stdout.lines.map(&:chomp)
    assert_equal "Fizzy::Error", lines.first
    assert_equal "Unknown profile missing", lines.second
  end
end
