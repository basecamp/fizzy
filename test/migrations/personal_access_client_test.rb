require "test_helper"
require Rails.root.join("db/migrate/20261015120100_backfill_token_digests")
require Rails.root.join("db/migrate/20261016120000_create_personal_access_client")
require Rails.root.join("db/migrate/20261016120100_backfill_personal_access_client")

class PersonalAccessClientMigrationTest < ActiveSupport::TestCase
  setup do
    Oauth::Client.personal_access.delete_all

    @personal = identities(:david).access_tokens.create!(description: "Before the client", permission: :write)
    @personal.update_columns updated_at: 200.days.ago.round
    @grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
  end

  test "provisions the issuer once" do
    assert_difference("Oauth::Client.count", +1) { migrate CreatePersonalAccessClient, :up }
    assert_no_difference("Oauth::Client.count") { migrate CreatePersonalAccessClient, :up }

    issuer = Oauth::Client.personal_access.sole
    assert_equal "Personal Access Tokens", issuer.name
    assert issuer.trusted?
    assert_not issuer.dynamically_registered?
    assert_equal "none", issuer.token_endpoint_auth_method
    assert_empty issuer.grant_types
    assert issuer.valid?
  end

  test "the backfill gives client-less tokens the issuer, keeping their string, digest, reach, non-expiry and updated_at" do
    kept = %w[ token token_digest refresh_token_digest permission expires_at description updated_at ]
    before = @personal.reload.attributes.slice(*kept)
    migrate CreatePersonalAccessClient, :up

    assert_no_changes -> { @grant.reload.attributes } do
      migrate BackfillPersonalAccessClient, :up
    end

    @personal.reload
    assert_equal Oauth::Client.personal_access.sole, @personal.oauth_client
    assert_equal before, @personal.attributes.slice(*kept)
    assert_nil @personal.expires_at
    assert @personal.personal?

    assert_equal @personal, Identity::AccessToken.find_honored(before["token"])
    assert @personal.allows?("POST")
  end

  test "the backfill reruns over tokens written client-less since" do
    migrate CreatePersonalAccessClient, :up
    migrate BackfillPersonalAccessClient, :up

    later = identities(:kevin).access_tokens.create!(description: "From older code")
    assert_nil later.oauth_client_id

    migrate BackfillPersonalAccessClient, :up
    assert_equal Oauth::Client.personal_access.sole, later.reload.oauth_client
  end

  test "the backfill refuses to run before the issuer exists" do
    assert_raises(RuntimeError) { migrate BackfillPersonalAccessClient, :up }
    assert_nil @personal.reload.oauth_client_id
  end

  test "down hands the tokens back to the client-less form and removes the issuer" do
    migrate CreatePersonalAccessClient, :up
    migrate BackfillPersonalAccessClient, :up

    assert_no_changes -> { @personal.reload.updated_at } do
      migrate BackfillPersonalAccessClient, :down
      migrate CreatePersonalAccessClient, :down
    end

    assert_nil @personal.reload.oauth_client_id
    assert @personal.personal?
    assert_equal oauth_clients(:mcp_client), @grant.reload.oauth_client
    assert_not Oauth::Client.personal_access.exists?
  end

  # BackfillTokenDigests is rerun to digest tokens production writes in
  # plaintext only. Once those have the issuer, the rerun must still treat them
  # as personal and keep the plaintext production reads.
  # Code that knows the issuer may still be serving a request that looked it
  # up just before down removed it.
  test "down leaves no token naming the removed issuer, even one issued as it went" do
    migrate CreatePersonalAccessClient, :up
    migrate BackfillPersonalAccessClient, :up
    in_flight = nil
    # Mocha stubs take no implementation, so the matcher both deletes the
    # issuer and issues the in-flight token, then matches.
    CreatePersonalAccessClient::Client.any_instance.stubs(:delete).with do
      client = CreatePersonalAccessClient::Client.find_by!(client_id: Oauth::Client::PERSONAL_ACCESS_CLIENT_ID)
      CreatePersonalAccessClient::Client.where(id: client.id).delete_all
      in_flight = identities(:david).access_tokens.create!(oauth_client_id: client.id)
    end

    migrate CreatePersonalAccessClient, :down

    assert_not Oauth::Client.personal_access.exists?
    assert_nil @personal.reload.oauth_client_id
    assert_nil in_flight.reload.oauth_client_id
    assert in_flight.personal?
  end

  test "rerunning the digest backfill keeps a client-backed personal token's plaintext" do
    migrate CreatePersonalAccessClient, :up
    migrate BackfillPersonalAccessClient, :up
    @personal.update_columns token: "legacyPersonalToken0123456789", token_digest: nil

    migrate BackfillTokenDigests, :up

    @personal.reload
    assert_equal "legacyPersonalToken0123456789", @personal.token
    assert_equal TokenDigester.digest("legacyPersonalToken0123456789"), @personal.token_digest
  end

  private
    def migrate(migration, direction)
      ActiveRecord::Migration.suppress_messages { migration.new.migrate(direction) }
    end
end
