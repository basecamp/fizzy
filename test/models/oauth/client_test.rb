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

  test "dynamically registered clients reject https loopback regardless of host case" do
    client = Oauth::Client.new(
      name: "Cased Loopback",
      redirect_uris: %w[ https://LOCALHOST:8888/callback ],
      dynamically_registered: true
    )
    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "must be an https or local loopback URI for dynamically registered clients"
  end

  test "dynamically registered clients reject percent-encoded https loopback" do
    client = Oauth::Client.new(
      name: "Encoded Loopback",
      redirect_uris: %w[ https://%6cocalhost:8888/callback ],
      dynamically_registered: true
    )
    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "must be an https or local loopback URI for dynamically registered clients"
  end

  test "dynamically registered clients name their redirect authority plainly" do
    %w[ https://%65vil.example/callback https://user:secret@connector.example.com/callback http://user@127.0.0.1:8888/callback
        https://connector.example.com:65536/callback https://connector.example.com:0/callback http://%5B%3A%3A1%5D:8888/callback ].each do |uri|
      client = Oauth::Client.new(name: "Unplain", redirect_uris: [ uri ], dynamically_registered: true)

      assert_not client.valid?, uri
      assert_includes client.errors[:redirect_uris], "must be an https or local loopback URI for dynamically registered clients", uri
    end

    %w[ https://connector.example.com:8443/callback https://Connector.Example.com/callback http://[::1]:8888/callback http://localhost/callback ].each do |uri|
      assert Oauth::Client.new(name: "Plain", redirect_uris: [ uri ], dynamically_registered: true).valid?, uri
    end
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
  end

  test "allows_redirect? lets only the port vary for loopback clients" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback ])
    assert_not client.allows_redirect?("http://localhost:7777/callback")
    assert_not client.allows_redirect?("http://[::1]:7777/callback")
    assert_not client.allows_redirect?("http://127.0.0.1:9999/callback?x=1")

    localhost = Oauth::Client.new(redirect_uris: %w[ http://localhost:8888/callback ])
    assert localhost.allows_redirect?("http://localhost:9999/callback")

    with_query = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback?app=cli ])
    assert with_query.allows_redirect?("http://127.0.0.1:9999/callback?app=cli")
    assert_not with_query.allows_redirect?("http://127.0.0.1:9999/callback")
    assert_not with_query.allows_redirect?("http://127.0.0.1:9999/callback?app=cli&code=injected")
  end

  test "name is limited to 255 characters" do
    assert Oauth::Client.new(name: "a" * 255, redirect_uris: %w[ http://127.0.0.1/cb ]).valid?

    client = Oauth::Client.new(name: "a" * 256, redirect_uris: %w[ http://127.0.0.1/cb ])
    assert_not client.valid?
    assert client.errors[:name].any?
  end

  test "allows_redirect? varies the port only for http loopback redirects" do
    client = Oauth::Client.new(redirect_uris: %w[ https://127.0.0.1:8443/callback ])
    assert client.allows_redirect?("https://127.0.0.1:8443/callback")
    assert_not client.allows_redirect?("https://127.0.0.1:9443/callback")
  end

  test "allows_redirect? never varies a loopback port onto different userinfo" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback https://connector.example.com/callback ])
    assert_not client.allows_redirect?("http://alice:secret@127.0.0.1:9999/callback")
    assert_not client.allows_redirect?("http://alice@127.0.0.1:8888/callback")
  end

  test "allows_redirect? never varies a loopback port out of the usable range" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback https://connector.example.com/callback ])
    assert client.allows_redirect?("http://127.0.0.1:65535/callback")
    assert_not client.allows_redirect?("http://127.0.0.1:65536/callback")
    assert_not client.allows_redirect?("http://127.0.0.1:0/callback")
  end

  test "allows_redirect? requires matching path for loopback flexibility" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback ])
    assert_not client.allows_redirect?("http://127.0.0.1:9999/other")
  end

  test "allows_redirect? never varies a loopback port onto a fragment" do
    client = oauth_clients(:mcp_client)
    assert_not client.allows_redirect?("http://127.0.0.1:9999/callback#fragment")
    assert_not client.allows_redirect?("http://127.0.0.1:9999/callback#")
  end

  test "allows_redirect? keeps loopback flexibility for mixed registrations" do
    client = Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1:8888/callback https://connector.example.com/callback ])
    assert client.allows_redirect?("http://127.0.0.1:9999/callback")
    assert client.allows_redirect?("https://connector.example.com/callback")
    assert_not client.allows_redirect?("https://connector.example.com:8443/callback")

    https_loopback = Oauth::Client.new(redirect_uris: %w[ https://127.0.0.1:8443/callback https://connector.example.com/callback ])
    assert https_loopback.allows_redirect?("https://127.0.0.1:8443/callback")
    assert_not https_loopback.allows_redirect?("https://127.0.0.1:9443/callback")
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

  test "access_tokens are the tokens issued to the client" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)

    assert_equal [ token ], client.access_tokens.to_a
  end
end
