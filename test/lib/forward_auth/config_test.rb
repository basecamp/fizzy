# frozen_string_literal: true

require "test_helper"

module ForwardAuth
  class ConfigTest < ActiveSupport::TestCase
    Request = Struct.new(:remote_ip, :headers, keyword_init: true)

    test "trusted? returns false when Forward Auth is disabled" do
      config = Config.new(enabled: false, trusted_ips: [ "127.0.0.0/8" ])
      request = Request.new(remote_ip: "127.0.0.1", headers: {})

      assert_not config.trusted?(request)
    end

    test "trusted? returns false when enabled but no trust mechanism configured" do
      config = Config.new(enabled: true, trusted_ips: [], secret_header: nil, secret: nil)
      request = Request.new(remote_ip: "127.0.0.1", headers: {})

      assert_not config.trusted?(request)
    end

    test "trusted? returns true when enabled and IP in trusted_ips" do
      config = Config.new(enabled: true, trusted_ips: [ "127.0.0.0/8" ])
      request = Request.new(remote_ip: "127.0.0.1", headers: {})

      assert config.trusted?(request)
    end

    test "trusted? returns false when enabled and IP not in trusted_ips" do
      config = Config.new(enabled: true, trusted_ips: [ "10.0.0.0/8" ])
      request = Request.new(remote_ip: "127.0.0.1", headers: {})

      assert_not config.trusted?(request)
    end

    test "trusted? returns true when enabled and secret header matches" do
      config = Config.new(
        enabled: true,
        trusted_ips: [],
        secret_header: "X-Forward-Auth-Verified",
        secret: "my-secret"
      )
      request = Request.new(
        remote_ip: "192.168.1.1",
        headers: { "X-Forward-Auth-Verified" => "my-secret" }
      )

      assert config.trusted?(request)
    end

    test "trusted? returns false when secret header does not match" do
      config = Config.new(
        enabled: true,
        trusted_ips: [ "127.0.0.0/8" ],
        secret_header: "X-Forward-Auth-Verified",
        secret: "my-secret"
      )
      request = Request.new(
        remote_ip: "127.0.0.1",
        headers: { "X-Forward-Auth-Verified" => "wrong" }
      )

      assert_not config.trusted?(request)
    end

    test "default_role falls back to member when invalid" do
      config = Config.new(enabled: true, trusted_ips: [ "127.0.0.1" ], default_role: "invalid_role")

      assert_equal "member", config.default_role
    end
  end
end
