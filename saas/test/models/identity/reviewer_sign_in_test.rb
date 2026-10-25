require "test_helper"

class Identity::ReviewerSignInTest < ActiveSupport::TestCase
  setup do
    @code = Identity::ReviewerSignIn.generate_code
    @identity = identities(:kevin)
    configure email_address: @identity.email_address, code_digest: Identity::ReviewerSignIn.digest(@code)
  end

  teardown { configure email_address: nil, code_digest: nil }

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
    assert_empty @identity.access_tokens.reload
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

  private
    def configure(email_address:, code_digest:)
      Rails.application.config.x.reviewer_sign_in.email_address = email_address
      Rails.application.config.x.reviewer_sign_in.code_digest = code_digest
    end
end
