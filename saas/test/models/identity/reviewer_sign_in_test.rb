require "test_helper"

class Identity::ReviewerSignInTest < ActiveSupport::TestCase
  setup do
    @code = Identity::ReviewerSignIn.generate_code
    @identity = identities(:kevin)
    configure email_address: @identity.email_address, code_digest: Identity::ReviewerSignIn.digest(@code)
  end

  teardown { configure email_address: nil, code_digest: nil, code_digests: nil }

  test "authenticates the configured identity with its code" do
    assert_equal @identity, Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: @code)
  end

  test "normalizes the code as an emailed code is" do
    assert_equal @identity, Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: " #{@code.downcase} ")
  end

  test "matches the email address case-insensitively" do
    assert_equal @identity, Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address.upcase, code: @code)
  end

  test "refuses a wrong code" do
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: Identity::ReviewerSignIn.generate_code)
  end

  test "refuses the code for any other identity" do
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: identities(:jason).email_address, code: @code)
  end

  test "is off unless both the email address and the digest are configured" do
    configure email_address: @identity.email_address, code_digest: nil
    assert_not Identity::ReviewerSignIn.configured?
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: @code)

    configure email_address: nil, code_digest: Identity::ReviewerSignIn.digest(@code)
    assert_not Identity::ReviewerSignIn.configured?
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: @code)
  end

  test "refuses blank input even when a blank code's digest is configured" do
    configure email_address: @identity.email_address, code_digest: Identity::ReviewerSignIn.digest("")

    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: "")
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: "!!-- ")
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: "", code: @code)
  end

  test "generates a 16-character code from the emailed code's alphabet" do
    code = Identity::ReviewerSignIn.generate_code

    assert_equal 16, code.length
    assert_equal code, MagicLink::Code.sanitize(code)
  end

  test "signs the configured identity out everywhere, and no one else" do
    @identity.sessions.create!
    @identity.transfer_id
    @identity.access_tokens.create!(description: "Reviewer", permission: :read)
    other_tokens = identities(:jason).access_tokens.count
    other_sessions = identities(:jason).sessions.count
    Identity.any_instance.expects(:close_remote_connections).once

    assert_operator Identity::ReviewerSignIn.sign_out_everywhere, :>, 0
    assert_empty @identity.sessions.reload
    assert_empty @identity.access_tokens.personal.reload
    assert_empty @identity.passkeys.reload
    assert_empty @identity.transfers.reload
    assert_equal other_tokens, identities(:jason).access_tokens.count
    assert_equal other_sessions, identities(:jason).sessions.count
  end

  test "signing out resets the join codes of the reviewer's accounts, and no others" do
    reviewer_codes = @identity.accounts.map { |account| account.join_code.code }
    other = Account::JoinCode.where.not(account: @identity.accounts).first
    other_code = other&.code

    Identity::ReviewerSignIn.sign_out_everywhere

    assert_empty @identity.accounts.map { |account| account.join_code.reload.code } & reviewer_codes
    assert_equal other_code, other&.reload&.code
  end

  test "lists the active members of the reviewer's accounts, including one who joined during a review" do
    account = @identity.accounts.first
    joiner = account.users.create!(name: "Code holder", identity: Identity.create!(email_address: "code-holder@example.com"), role: :member)

    members = Identity::ReviewerSignIn.members_of_reviewer_accounts

    assert_equal @identity.accounts.sort_by(&:id), members.keys.sort_by(&:id)
    assert_includes members[account], joiner
    assert members.values.flatten.all?(&:active?)
  end

  test "lists no members when unconfigured" do
    configure email_address: nil, code_digest: nil

    assert_equal({}, Identity::ReviewerSignIn.members_of_reviewer_accounts)
  end

  test "signing out still works after the digest is cleared" do
    @identity.sessions.create!
    configure email_address: @identity.email_address, code_digest: nil

    assert_operator Identity::ReviewerSignIn.sign_out_everywhere, :>, 0
    assert_empty @identity.sessions.reload
  end

  test "signing out does nothing when unconfigured" do
    configure email_address: nil, code_digest: nil

    assert_no_difference -> { Session.count } do
      assert_equal 0, Identity::ReviewerSignIn.sign_out_everywhere
    end
  end

  test "signing out leaves the reviewer's connected apps connected" do
    grant = @identity.access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    personal = @identity.access_tokens.create!(description: "Reviewer", permission: :read)

    Identity::ReviewerSignIn.sign_out_everywhere

    assert Identity::AccessToken.exists?(grant.id), "signing out never disconnects an app"
    assert_not Identity::AccessToken.exists?(personal.id)
  end

  test "lists the apps connected as each reviewer" do
    grant = @identity.access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_equal({ @identity => [ grant ] }, Identity::ReviewerSignIn.oauth_grants_of_reviewers)
  end

  test "disconnects the named reviewer's apps only when asked, and no one else's" do
    other = identities(:mike)
    configure email_address: nil, code_digest: nil, code_digests: "#{@identity.email_address}=#{Identity::ReviewerSignIn.digest(@code)} #{other.email_address}=#{Identity::ReviewerSignIn.digest(@code)}"
    grant = @identity.access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    others_grant = other.access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    staff_grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_equal 0, Identity::ReviewerSignIn.revoke_oauth_grants(nil), "it needs a reviewer named"
    assert_equal 0, Identity::ReviewerSignIn.revoke_oauth_grants(identities(:david).email_address), "only a reviewer's apps"
    assert_equal 1, Identity::ReviewerSignIn.revoke_oauth_grants(@identity.email_address.upcase)

    assert_not Identity::AccessToken.exists?(grant.id)
    assert Identity::AccessToken.exists?(others_grant.id)
    assert Identity::AccessToken.exists?(staff_grant.id)
  end

  test "authenticates each listed reviewer with its own code, and not another's" do
    other = identities(:mike)
    other_code = Identity::ReviewerSignIn.generate_code
    configure email_address: nil, code_digest: nil, code_digests: "#{@identity.email_address}=#{Identity::ReviewerSignIn.digest(@code)}, #{other.email_address}=#{Identity::ReviewerSignIn.digest(other_code).upcase}"

    assert_equal @identity, Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: @code)
    assert_equal other, Identity::ReviewerSignIn.authenticate(email_address: other.email_address, code: other_code)
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: other_code)
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: other.email_address, code: @code)
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: identities(:jz).email_address, code: @code)
  end

  test "the single pair still works beside the list, and the list wins where both name an address" do
    other = identities(:mike)
    other_code = Identity::ReviewerSignIn.generate_code
    configure email_address: @identity.email_address, code_digest: Identity::ReviewerSignIn.digest(@code), code_digests: "#{other.email_address}=#{Identity::ReviewerSignIn.digest(other_code)}"

    assert_equal @identity, Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: @code)
    assert_equal other, Identity::ReviewerSignIn.authenticate(email_address: other.email_address, code: other_code)

    configure email_address: @identity.email_address, code_digest: Identity::ReviewerSignIn.digest(@code), code_digests: "#{@identity.email_address}=#{Identity::ReviewerSignIn.digest(other_code)}"
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: @code)
    assert_equal @identity, Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: other_code)
  end

  test "compares the presented code with every reviewer's in constant time" do
    configure email_address: nil, code_digest: nil, code_digests: "#{@identity.email_address}=#{Identity::ReviewerSignIn.digest(@code)} #{identities(:mike).email_address}=#{Identity::ReviewerSignIn.digest(@code)}"
    ActiveSupport::SecurityUtils.expects(:secure_compare).times(4).returns(false)

    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: Identity::ReviewerSignIn.generate_code)
  end

  test "a listed address with no digest is a reviewer that no code signs in" do
    configure email_address: nil, code_digest: nil, code_digests: "#{@identity.email_address}= #{identities(:mike).email_address}"

    assert Identity::ReviewerSignIn.reviewer?(@identity)
    assert Identity::ReviewerSignIn.reviewer?(identities(:mike))
    assert_not Identity::ReviewerSignIn.reviewer?(identities(:jz))
    assert_not Identity::ReviewerSignIn.configured?
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: @code)
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: @identity.email_address, code: "")
  end

  test "signs out only the reviewer named, and no one when the address isn't a reviewer's" do
    other = identities(:mike)
    configure email_address: nil, code_digest: nil, code_digests: "#{@identity.email_address}=#{Identity::ReviewerSignIn.digest(@code)} #{other.email_address}=#{Identity::ReviewerSignIn.digest(@code)}"
    @identity.sessions.create!
    other.sessions.create!

    assert_no_difference -> { Session.count } do
      assert_equal 0, Identity::ReviewerSignIn.sign_out_everywhere(identities(:david).email_address)
    end

    assert_operator Identity::ReviewerSignIn.sign_out_everywhere(@identity.email_address), :>, 0
    assert_empty @identity.sessions.reload
    assert_not_empty other.sessions.reload
  end

  test "adds a reviewer to the list, carrying in the single pair, or replaces its digest" do
    digest = Identity::ReviewerSignIn.digest(@code)

    assert_equal "#{@identity.email_address}=#{digest},new@example.com=abc", Identity::ReviewerSignIn.code_digests_with(" New@Example.com ", "abc")
    assert_equal "#{@identity.email_address}=abc", Identity::ReviewerSignIn.code_digests_with(@identity.email_address, "abc")
  end

  private
    def configure(email_address:, code_digest:, code_digests: nil)
      Rails.application.config.x.reviewer_sign_in.email_address = email_address
      Rails.application.config.x.reviewer_sign_in.code_digest = code_digest
      Rails.application.config.x.reviewer_sign_in.code_digests = code_digests
    end
end
