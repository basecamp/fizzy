require "test_helper"
require Rails.root.join("db/migrate/20261017130000_drop_identity_access_token_plaintext")

# DropIdentityAccessTokenPlaintext runs while processes still serve the code
# that shipped with BackfillRemainingTokenDigests, which ignores both plaintext
# columns. With partial_inserts off, a process names every column it has cached
# on each INSERT, so one that loaded identity_access_tokens' columns before the
# migration must still create tokens after it.
class DropIdentityAccessTokenPlaintextTest < ActiveSupport::TestCase
  # Each step is DDL, which MySQL commits on its own.
  self.use_transactional_tests = false

  # identity_access_tokens as the code before this migration models it.
  class PreviousAccessToken < ApplicationRecord
    self.table_name = "identity_access_tokens"
    self.ignored_columns = %w[ token refresh_token ]
  end

  setup do
    migrate :down
    PreviousAccessToken.reset_column_information.then { PreviousAccessToken.columns }
  end

  teardown do
    migrate :up if ActiveRecord::Base.connection.column_exists?(:identity_access_tokens, :token)
    [ PreviousAccessToken, Identity::AccessToken ].each(&:reset_column_information)
    PreviousAccessToken.where(description: "Cached before the migration").delete_all
  end

  test "drops both plaintext columns" do
    migrate :up

    assert_not ActiveRecord::Base.connection.column_exists?(:identity_access_tokens, :token)
    assert_not ActiveRecord::Base.connection.column_exists?(:identity_access_tokens, :refresh_token)
  end

  test "a process that cached identity_access_tokens' columns before it creates tokens after it" do
    migrate :up

    assert_difference -> { PreviousAccessToken.count } do
      PreviousAccessToken.create! identity_id: identities(:david).id, permission: "write", description: "Cached before the migration",
        token_digest: TokenDigester.digest(SecureRandom.base58(24))
    end
  end

  private
    def migrate(direction)
      DropIdentityAccessTokenPlaintext.new.tap { |migration| migration.verbose = false }.migrate(direction)
    end
end
