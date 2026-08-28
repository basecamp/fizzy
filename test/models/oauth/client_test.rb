require "test_helper"

class Oauth::ClientTest < ActiveSupport::TestCase
  test "generates client_id on create" do
    client = Oauth::Client.create!(name: "Test", redirect_uris: %w[ http://127.0.0.1:8888/callback ])
    assert_equal 32, client.client_id.length
    assert_match(/\A[a-zA-Z0-9]+\z/, client.client_id)
  end

  test "client_id must be unique" do
    existing = oauth_clients(:mcp_client)
    client = Oauth::Client.new(name: "Dupe", client_id: existing.client_id, redirect_uris: %w[ http://127.0.0.1/cb ])
    assert_not client.valid?
    assert_includes client.errors[:client_id], "has already been taken"
  end

  test "name is required" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1/cb ])
    assert_not client.valid?
    assert_includes client.errors[:name], "can't be blank"
  end

  test "redirect_uris required" do
    client = Oauth::Client.new(name: "Test")
    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "can't be blank"
  end

  test "dynamically registered clients can use https URIs" do
    client = Oauth::Client.new(
      name: "Hosted Connector",
      redirect_uris: %w[ https://connector.example.com/callback ],
      dynamically_registered: true
    )
    assert client.valid?
  end

  test "dynamically registered clients reject plain http for non-loopback hosts" do
    client = Oauth::Client.new(
      name: "External",
      redirect_uris: %w[ http://example.com/callback ],
      dynamically_registered: true
    )
    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "must be an https or local loopback URI for dynamically registered clients"
  end

  test "dynamically registered clients reject https loopback" do
    client = Oauth::Client.new(
      name: "HTTPS Loopback",
      redirect_uris: %w[ https://127.0.0.1:8888/callback ],
      dynamically_registered: true
    )
    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "must be an https or local loopback URI for dynamically registered clients"
  end

  test "dynamically registered clients reject custom schemes" do
    client = Oauth::Client.new(
      name: "Native App",
      redirect_uris: %w[ myapp://callback ],
      dynamically_registered: true
    )
    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "must be an https or local loopback URI for dynamically registered clients"
  end

  test "redirect URIs must not contain fragments" do
    client = Oauth::Client.new(
      name: "Fragment",
      redirect_uris: %w[ http://127.0.0.1:8888/callback#section ],
      dynamically_registered: true
    )
    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "must not contain fragments"
  end

  test "redirect URIs must not contain empty fragments" do
    client = Oauth::Client.new(
      name: "Empty Fragment",
      redirect_uris: %w[ https://connector.example.com/callback# ],
      dynamically_registered: true
    )
    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "must not contain fragments"
  end

  test "dynamically registered clients can use 127.0.0.1" do
    client = Oauth::Client.new(
      name: "Loopback",
      redirect_uris: %w[ http://127.0.0.1:9999/callback ],
      dynamically_registered: true
    )
    assert client.valid?
  end

  test "dynamically registered clients can use localhost" do
    client = Oauth::Client.new(
      name: "Localhost",
      redirect_uris: %w[ http://localhost:9999/callback ],
      dynamically_registered: true
    )
    assert client.valid?
  end

  test "dynamically registered clients can use IPv6 loopback" do
    client = Oauth::Client.new(
      name: "IPv6",
      redirect_uris: %w[ http://[::1]:9999/callback ],
      dynamically_registered: true
    )
    assert client.valid?
  end

  test "allows_redirect? matches exact URI" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback ])
    assert client.allows_redirect?("http://127.0.0.1:8888/callback")
    assert_not client.allows_redirect?("http://127.0.0.1:8888/other")
  end

  test "allows_redirect? allows different ports for loopback clients" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback ])
    assert client.allows_redirect?("http://127.0.0.1:9999/callback")
    assert client.allows_redirect?("http://localhost:7777/callback")
  end

  test "allows_redirect? requires matching path for loopback flexibility" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback ])
    assert_not client.allows_redirect?("http://127.0.0.1:9999/other")
  end

  test "allows_redirect? keeps loopback flexibility for mixed registrations" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback https://connector.example.com/callback ])
    assert client.allows_redirect?("http://127.0.0.1:9999/callback")
    assert client.allows_redirect?("https://connector.example.com/callback")
    assert_not client.allows_redirect?("https://connector.example.com:8443/callback")
  end

  test "allows_scope? checks client scopes" do
    client = Oauth::Client.new(scopes: %w[ read write ])
    assert client.allows_scope?("read")
    assert client.allows_scope?("write")
    assert client.allows_scope?("read write")
    assert_not client.allows_scope?("admin")
    assert_not client.allows_scope?("read admin")
    assert_not client.allows_scope?("")
  end

  test "default scopes are set" do
    client = Oauth::Client.new(name: "Test", redirect_uris: %w[ http://127.0.0.1/cb ])
    assert_equal %w[ read ], client.scopes
  end

  test "trusted scope" do
    trusted = Oauth::Client.trusted
    assert trusted.all?(&:trusted?)
  end

  test "dynamically_registered scope" do
    dcr_clients = Oauth::Client.dynamically_registered
    assert dcr_clients.all?(&:dynamically_registered?)
  end
end
