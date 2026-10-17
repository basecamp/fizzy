require "test_helper"
require Rails.root.join("db/migrate/20261015120100_backfill_token_digests")

class BackfillTokenDigestsTest < ActiveSupport::TestCase
  setup do
    @personal = identities(:david).access_tokens.create!(description: "Before digests")
    @personal.update_columns token: "legacyPersonalToken0123456789", token_digest: nil, updated_at: 3.days.ago.round

    @grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    @grant.update_columns token: "legacyAccessToken0123456789", token_digest: nil, updated_at: 80.days.ago.round
  end

  test "digests every undigested token, keeping a personal token's plaintext and clearing a grant's" do
    backfill

    @personal.reload
    assert_equal TokenDigester.digest("legacyPersonalToken0123456789"), @personal.token_digest
    assert_equal "legacyPersonalToken0123456789", @personal.token

    @grant.reload
    assert_equal TokenDigester.digest("legacyAccessToken0123456789"), @grant.token_digest
    assert_nil @grant.token
  end

  # A grant's updated_at is its idle-lapse clock.
  test "leaves updated_at alone" do
    assert_no_changes -> { [ @personal.reload.updated_at, @grant.reload.updated_at ] } do
      backfill
    end
  end

  test "leaves digested tokens alone, so it can run again" do
    digested = identity_access_tokens(:davids_api_token)

    assert_no_changes -> { digested.reload.attributes } do
      backfill
      backfill
    end
  end

  test "the backfilled token authenticates by digest" do
    backfill

    assert_equal @personal, Identity::AccessToken.find_honored("legacyPersonalToken0123456789")
    assert_equal @grant, Identity::AccessToken.find_by_raw_token("legacyAccessToken0123456789")
  end

  test "refuses duplicate tokens before digesting anything, without naming them" do
    copy = identities(:kevin).access_tokens.create!(description: "Copy")
    copy.update_columns token: "legacyPersonalToken0123456789", token_digest: nil

    error = assert_raises(RuntimeError) { backfill }

    assert_match @personal.id, error.message
    assert_match copy.id, error.message
    assert_no_match(/legacyPersonalToken/, error.message)
    assert_nil @personal.reload.token_digest
    assert_nil @grant.reload.token_digest
  end

  private
    def backfill
      BackfillTokenDigests.new.tap { |migration| migration.verbose = false }.up
    end
end
