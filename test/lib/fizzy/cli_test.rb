require "test_helper"
require "tmpdir"
require_relative "../../../cli/lib/fizzy/cli"

class FizzyCliTest < ActiveSupport::TestCase
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
  test "auth bootstrap saves a profile and prints JSON" do
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      response = {
        "token" => "secret-token",
        "account" => { "slug" => "1234567" },
        "user" => { "name" => "Board Agent", "email_address" => "agent@example.com" },
        "profile" => {
          "base_url" => "https://app.example.test",
          "account_slug" => "1234567",
          "default_board_id" => "board-1"
        }
      }

      Fizzy::Client.any_instance.expects(:request).with(
        :post,
        "https://bootstrap.example.test/claim",
        params: { email_address: "agent@example.com", name: "Board Agent", profile_name: nil }
      ).returns(response)

      stdout, = capture_io do
        with_env("FIZZY_CONFIG" => config_path) do
          Fizzy::AuthCommand.start(%w[bootstrap https://bootstrap.example.test/claim --email agent@example.com --name Board\ Agent --profile agent --json])
        end
      end

      body = JSON.parse(stdout)
      store = Fizzy::ConfigStore.new(path: config_path)

      assert_equal "agent", body["profile_name"]
      assert_equal "secret-token", store.profile("agent")["token"]
      assert_equal "board-1", store.profile("agent")["default_board_id"]
    end
  end

  test "whoami uses the active profile and prints JSON" do
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      store = Fizzy::ConfigStore.new(path: config_path)
      store.save_profile("agent", {
        "base_url" => "https://app.example.test",
        "account_slug" => "1234567",
        "token" => "secret-token"
      })

      Fizzy::Client.any_instance.expects(:request).with(:get, "/my/identity", params: nil).returns(
        { "id" => "identity-1", "accounts" => [ { "slug" => "1234567" } ] }
      )

      stdout, = capture_io do
        with_env("FIZZY_CONFIG" => config_path) do
          Fizzy::CLI.start(%w[whoami --json])
        end
      end

      body = JSON.parse(stdout)
      assert_equal "identity-1", body["id"]
      assert_equal "1234567", body["accounts"].first["slug"]
    end
  end

  test "api command prefixes account path when requested" do
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      store = Fizzy::ConfigStore.new(path: config_path)
      store.save_profile("agent", {
        "base_url" => "https://app.example.test",
        "account_slug" => "1234567",
        "token" => "secret-token"
      })

      Fizzy::Client.any_instance.expects(:request).with(
        "POST",
        "/1234567/boards",
        params: { "name" => "Experimental" }
      ).returns({ "id" => "board-1", "name" => "Experimental" })

      stdout, = capture_io do
        with_env("FIZZY_CONFIG" => config_path) do
          Fizzy::CLI.start(%w[api POST boards --account-scope --data {"name":"Experimental"} --json])
        end
      end

      body = JSON.parse(stdout)
      assert_equal "board-1", body["id"]
    end
  end
end
