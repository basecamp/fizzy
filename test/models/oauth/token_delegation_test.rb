require "test_helper"

class Oauth::TokenDelegationTest < ActiveSupport::TestCase
  RESOURCE = "https://mcp.example.com/mcp"

  setup do
    @saved_resources = Rails.application.config.x.oauth.mcp_resources
    Rails.application.config.x.oauth.mcp_resources = [ RESOURCE ]

    @client = Oauth::Client.provision_mcp_client!(protected_resource: RESOURCE)
    @subject = identities(:david).access_tokens.create! \
      oauth_client: oauth_clients(:mcp_client), permission: :write, audience: RESOURCE, account: accounts("37s")
  end

  teardown do
    Rails.application.config.x.oauth.mcp_resources = @saved_resources
  end

  test "mint issues one token under the subject grant, with no refresh token and no client touch" do
    assert_no_changes -> { @client.reload.updated_at } do
      @token = delegation.validate!.mint!
    end

    assert @token.delegated?
    assert @token.raw_token.start_with?("fizzy_dt_")
    assert_nil @token.refresh_token_digest
    assert_equal @subject, @token.delegated_from
  end

  test "the token lives at most five minutes" do
    token = delegation.validate!.mint!

    assert_operator token.expires_at, :<=, Oauth::TokenDelegation::TTL_CAP.from_now
  end

  test "a delegated token is honored only while its grant is" do
    token = delegation.validate!.mint!
    assert token.honored?

    @subject.update_columns updated_at: (Identity::AccessToken::REFRESH_IDLE_LIMIT + 1.day).ago
    assert_not token.reload.honored?
  end

  test "a delegated token the replica doesn't honor is judged again on the primary, grant included" do
    token = delegation.validate!.mint!
    judged_on = []
    on_primary = false

    Identity::AccessToken.any_instance.stubs(:honored_delegation?).with { judged_on << on_primary }.returns(false).then.returns(true)
    on_the_primary -> { on_primary = true } do
      assert_equal token, Identity::AccessToken.find_honored(token.raw_token)
    end

    assert_equal [ false, true ], judged_on
  end

  test "an unknown token without the delegated prefix never costs a primary read" do
    ApplicationRecord.expects(:with_writing_role).never

    assert_nil Identity::AccessToken.find_honored("fizzy_at_unknown")
  end

  test "a malformed fizzy_dt_ token never costs a primary read" do
    minted = Identity::AccessToken.generate_token(:delegated)
    ApplicationRecord.expects(:with_writing_role).never

    [ "fizzy_dt_", "fizzy_dt_nothing", minted.chop, minted + "x", minted.sub(/.\z/, "0"), minted.sub(/.\z/, "l"), minted + "\n" ].each do |token|
      assert_nil Identity::AccessToken.find_honored(token), token.inspect
    end
  end

  test "a well-shaped but unknown fizzy_dt_ token costs one primary lookup" do
    ApplicationRecord.expects(:with_writing_role).once.returns(nil)

    assert_nil Identity::AccessToken.find_honored(Identity::AccessToken.generate_token(:delegated))
  end

  test "every minted delegated token has the shape the primary fallback admits" do
    assert_match Identity::AccessToken::DELEGATED_TOKEN, delegation.validate!.mint!.raw_token
  end

  test "a write token delegated from a grant since narrowed to read can't write" do
    token = delegation.validate!.mint!
    assert token.write?

    assert @subject.refresh(permission: "read")

    assert_not token.reload.honored?
  end

  test "a mint after a refresh narrowed the grant mints what the grant now holds" do
    delegation.validate!
    @subject.update_columns permission: "read"

    token = @delegation.mint!

    assert token.read?
    assert_equal "read", @delegation.scope
    assert token.honored?
  end

  test "a mint asking for write after a refresh narrowed the grant is refused" do
    delegation(requested_scope: "write").validate!
    @subject.update_columns permission: "read"

    error = assert_raises(Oauth::TokenDelegation::Refusal) { @delegation.mint! }
    assert_equal "invalid_scope", error.error
  end

  test "a mint racing the client's deletion is refused" do
    delegation.validate!
    @client.delete

    error = assert_raises(Oauth::TokenDelegation::Refusal) { @delegation.mint! }
    assert_equal "unauthorized_client", error.error
  end

  test "expired delegated tokens are cleaned up, and grants are not" do
    expired = delegation.validate!.mint!
    expired.update_columns expires_at: 2.hours.ago
    live = delegation.validate!.mint!

    Identity::AccessToken.cleanup_delegated

    assert_not Identity::AccessToken.exists?(expired.id)
    assert Identity::AccessToken.exists?(live.id)
    assert Identity::AccessToken.exists?(@subject.id)
  end

  test "the lapsed-grant sweep and Connected Apps see grants only" do
    token = delegation.validate!.mint!

    assert_not_includes Identity::AccessToken.grants, token
    assert_includes Identity::AccessToken.grants, @subject
  end

  test "provisioning converges the client and keeps its secret" do
    secret = @client.rotate_secret!

    client = Oauth::Client.provision_mcp_client!(protected_resource: RESOURCE)

    assert_equal @client, client
    assert client.authenticate_secret(secret)
    assert client.delegation_client?
    assert_empty client.redirect_uris
  end

  test "a second configured resource gets a client of its own, and can't take over the first's" do
    other = "https://other.example.com/mcp"
    Rails.application.config.x.oauth.mcp_resources = [ RESOURCE, other ]

    assert_raises(ArgumentError) { Oauth::Client.provision_mcp_client!(protected_resource: other) }
    assert_equal RESOURCE, @client.reload.protected_resource

    second = Oauth::Client.provision_mcp_client!(protected_resource: other, client_id: "fizzy-mcp-server-other")
    assert second.delegation_client?
    assert_not_equal @client, second
  end

  test "a client whose resource was dropped from the configuration may move to a new one" do
    moved = "https://mcp.example.com/v2/mcp"
    Rails.application.config.x.oauth.mcp_resources = [ moved ]

    client = Oauth::Client.provision_mcp_client!(protected_resource: moved)

    assert_equal @client, client
    assert_equal moved, client.protected_resource
  end

  test "a new client holds a secret nobody knows until one is minted" do
    assert @client.client_secret_digest.present?

    secret = @client.rotate_secret!

    assert secret.start_with?("fizzy_cs_")
    assert @client.reload.authenticate_secret(secret)
  end

  test "rotating a secret retires the old one" do
    old = @client.rotate_secret!
    @client.rotate_secret!

    assert_not @client.reload.authenticate_secret(old)
  end

  test "a self-registered client's secret can't be minted" do
    assert_raises(ArgumentError) { oauth_clients(:confidential_client).rotate_secret! }
  end

  test "a client that fronts no resource still needs a redirect" do
    client = Oauth::Client.new(name: "No redirects", redirect_uris: [])

    assert_not client.valid?
    assert client.errors[:redirect_uris].any?
  end

  private
    # Stands in for the writing role, which SQLite has no separate connection
    # for: runs the block, noting that it ran there.
    def on_the_primary(entered)
      ApplicationRecord.singleton_class.alias_method :with_writing_role_without_test, :with_writing_role
      ApplicationRecord.define_singleton_method(:with_writing_role) do |&block|
        entered.call
        block.call
      end
      yield
    ensure
      ApplicationRecord.singleton_class.alias_method :with_writing_role, :with_writing_role_without_test
      ApplicationRecord.singleton_class.remove_method :with_writing_role_without_test
    end

    def delegation(**options)
      @delegation = Oauth::TokenDelegation.new(client: @client, subject_token: @subject.raw_token, api_resource: ->(resource) { resource == "http://www.example.com" }, **options)
    end
end
