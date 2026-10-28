require "test_helper"

class Oauth::FirstPartyClientsTest < ActiveSupport::TestCase
  PRODUCTION = "https://mcp.fizzy.do/mcp"
  BETA1 = "https://beta1-mcp.fizzy-beta.com/mcp"

  setup do
    @saved_resources = Rails.application.config.x.oauth.mcp_resources
  end

  teardown do
    Rails.application.config.x.oauth.mcp_resources = @saved_resources
  end

  test "a converge creates the personal access client and the hosted MCP clients this install serves" do
    serve PRODUCTION, BETA1
    Oauth::Client.personal_access.delete_all

    clients = Oauth::FirstPartyClients.provision!

    assert_equal %w[ fizzy-personal-access fizzy-mcp-server fizzy-mcp-server-beta1 ], clients.map(&:client_id)
    assert clients.all?(&:previously_new_record?)
    assert_equal PRODUCTION, client("fizzy-mcp-server").protected_resource
    assert_equal BETA1, client("fizzy-mcp-server-beta1").protected_resource
    assert client("fizzy-mcp-server").delegation_client?
    assert client("fizzy-personal-access").trusted?
  end

  test "converging again changes nothing" do
    serve PRODUCTION, BETA1
    Oauth::FirstPartyClients.provision!
    before = Oauth::Client.order(:client_id).map(&:attributes)

    travel 1.minute do
      assert_no_difference -> { Oauth::Client.count } do
        clients = Oauth::FirstPartyClients.provision!
        assert clients.none?(&:previously_new_record?)
      end
    end

    assert_equal before, Oauth::Client.order(:client_id).map(&:attributes)
  end

  test "drift in any baseline attribute is reset" do
    serve PRODUCTION
    Oauth::FirstPartyClients.provision!

    client("fizzy-personal-access").update_columns token_endpoint_auth_method: "client_secret_post",
      client_secret_digest: TokenDigester.digest("stray"), redirect_uris: [ "https://evil.example.com/callback" ],
      scopes: %w[ read write admin ], trusted: false, dynamically_registered: true, client_id_metadata_document: true,
      metadata_etag: "etag", metadata_expires_at: 1.day.from_now, metadata_fetched_at: Time.current,
      protected_resource: PRODUCTION
    client("fizzy-mcp-server").update_columns token_endpoint_auth_method: "none", trusted: true,
      redirect_uris: [ "https://evil.example.com/callback" ], scopes: %w[ read ], dynamically_registered: true,
      client_id_metadata_document: true, metadata_etag: "etag"

    Oauth::FirstPartyClients.provision!

    %w[ fizzy-personal-access fizzy-mcp-server ].each do |client_id|
      expected = Oauth::FirstPartyClients.attributes_for(client_id)
      expected = expected.except(:client_secret_digest) if client_id == "fizzy-mcp-server"
      actual = client(client_id).attributes.symbolize_keys.slice(*expected.keys)

      assert_equal expected.except(:name), actual.except(:name), "#{client_id} kept its drift"
    end

    assert_equal Oauth::FirstPartyClients::BASELINE.keys.sort,
      (Oauth::Client.column_names.map(&:to_sym) - %i[ id client_id name created_at updated_at ]).sort,
      "every policy column is in the baseline"
  end

  test "a live secret survives a converge" do
    serve PRODUCTION
    secret = Oauth::FirstPartyClients.provision!.find { it.client_id == "fizzy-mcp-server" }.rotate_secret!

    Oauth::FirstPartyClients.provision!

    assert client("fizzy-mcp-server").authenticate_secret(secret)
    assert_not Oauth::FirstPartyClients.awaiting_secret?(client("fizzy-mcp-server"))
  end

  test "a new confidential client is reported as awaiting a secret, and a public one isn't" do
    serve PRODUCTION

    clients = Oauth::FirstPartyClients.provision!.index_by(&:client_id)

    assert Oauth::FirstPartyClients.awaiting_secret?(clients["fizzy-mcp-server"])
    assert_not Oauth::FirstPartyClients.awaiting_secret?(clients["fizzy-personal-access"])
  end

  test "a client stays awaiting a secret across converges until one is minted" do
    serve PRODUCTION
    Oauth::FirstPartyClients.provision!

    converged = Oauth::FirstPartyClients.provision!.find { it.client_id == "fizzy-mcp-server" }

    assert Oauth::FirstPartyClients.awaiting_secret?(converged)
    assert_not converged.authenticate_secret("")

    converged.rotate_secret!
    assert_not Oauth::FirstPartyClients.awaiting_secret?(converged.reload)
  end

  test "a client turned off by clearing its secret stays off" do
    serve PRODUCTION
    Oauth::FirstPartyClients.provision!
    client("fizzy-mcp-server").update_columns client_secret_digest: nil

    converged = Oauth::FirstPartyClients.provision!.find { it.client_id == "fizzy-mcp-server" }

    assert_nil client("fizzy-mcp-server").client_secret_digest
    assert Oauth::FirstPartyClients.awaiting_secret?(converged)
  end

  test "a client turned off by dropping its resource stays off, and isn't written" do
    serve PRODUCTION, BETA1
    Oauth::FirstPartyClients.provision!
    beta1 = client("fizzy-mcp-server-beta1")
    beta1.update_columns trusted: true

    serve PRODUCTION

    assert_no_changes -> { beta1.reload.attributes } do
      Oauth::FirstPartyClients.provision!
    end
    assert_not beta1.delegation_client?
  end

  test "a production converge creates no beta client" do
    serve PRODUCTION

    Oauth::FirstPartyClients.provision!

    assert Oauth::Client.exists?(client_id: "fizzy-mcp-server")
    assert_not Oauth::Client.exists?(client_id: "fizzy-mcp-server-beta1")
  end

  test "an install that serves no hosted MCP resource gets no MCP client" do
    serve "https://mcp.self-hosted.example.com/mcp"

    assert_equal %w[ fizzy-personal-access ], Oauth::FirstPartyClients.provision!.map(&:client_id)
    assert_not Oauth::Client.exists?(client_id: Oauth::FirstPartyClients::HOSTED_MCP_SERVERS.values)
  end

  test "a converge that fails partway writes nothing" do
    Oauth::Client.personal_access.delete_all

    assert_no_difference -> { Oauth::Client.count } do
      assert_raises ActiveRecord::RecordInvalid do
        Oauth::FirstPartyClients.converge! Oauth::FirstPartyClients.definitions([]).merge("fizzy-broken" => { name: "" })
      end
    end
  end

  test "a client fronting a configured resource isn't repointed" do
    serve PRODUCTION, "https://other.example.com/mcp"
    Oauth::FirstPartyClients.provision!

    assert_raises(ArgumentError) { Oauth::FirstPartyClients.provision_mcp_server!("https://other.example.com/mcp") }
    assert_equal PRODUCTION, client("fizzy-mcp-server").protected_resource
  end

  test "a hosted client isn't repointed from a destination that doesn't serve its resource" do
    serve PRODUCTION
    Oauth::FirstPartyClients.provision!
    serve "https://other.example.com/mcp"

    assert_raises(ArgumentError) { Oauth::FirstPartyClients.provision_mcp_server!("https://other.example.com/mcp") }
    assert_equal PRODUCTION, client("fizzy-mcp-server").protected_resource
  end

  test "a self-hosted MCP server may name the default client_id, as it may omit it" do
    serve "https://mcp.self-hosted.example.com/mcp"

    named = Oauth::FirstPartyClients.provision_mcp_server!("https://mcp.self-hosted.example.com/mcp", client_id: "fizzy-mcp-server")
    omitted = Oauth::FirstPartyClients.provision_mcp_server!("https://mcp.self-hosted.example.com/mcp")

    assert_equal "fizzy-mcp-server", named.client_id
    assert_equal named, omitted
  end

  test "a hosted resource and its client can't be provisioned apart" do
    serve PRODUCTION, BETA1, "https://other.example.com/mcp"

    assert_raises(ArgumentError) { Oauth::FirstPartyClients.provision_mcp_server!(PRODUCTION, client_id: "fizzy-mcp-server-other") }
    assert_raises(ArgumentError) { Oauth::FirstPartyClients.provision_mcp_server!("https://other.example.com/mcp", client_id: "fizzy-mcp-server-beta1") }
    assert_not Oauth::Client.exists?(client_id: %w[ fizzy-mcp-server-other fizzy-mcp-server-beta1 ])

    assert_equal "fizzy-mcp-server-beta1", Oauth::FirstPartyClients.provision_mcp_server!(BETA1).client_id
  end

  test "the personal access issuer made on first use matches the registry" do
    Oauth::Client.personal_access.delete_all

    issuer = Oauth::Client.personal_access_issuer

    assert_no_changes -> { issuer.reload.attributes } do
      Oauth::FirstPartyClients.provision!
    end
  end

  private
    def serve(*resources)
      Rails.application.config.x.oauth.mcp_resources = resources
    end

    def client(client_id)
      Oauth::Client.find_by!(client_id: client_id)
    end
end
