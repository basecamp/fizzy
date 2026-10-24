require "test_helper"
require Rails.root.join("db/migrate/20261015120200_drop_plaintext_oauth_credentials")

# DropPlaintextOauthCredentials runs against the production database while
# production still serves code from before this stack, and without restarting
# it. That code ignores no column, and with partial_inserts off it names every
# column it has cached on each INSERT. So a process that loaded
# identity_access_tokens' columns before the migration must still create
# tokens after it: the migration must not drop any of that table's columns.
class DropPlaintextOauthCredentialsTest < ActiveSupport::TestCase
  # Each step is DDL, which MySQL commits on its own.
  self.use_transactional_tests = false

  # identity_access_tokens as code from before this stack models it.
  class PreviousAccessToken < ApplicationRecord
    self.table_name = "identity_access_tokens"
  end

  setup do
    migrate :down
    [ PreviousAccessToken, Identity::AccessToken ].each { |model| model.reset_column_information.then { model.columns } }
  end

  teardown do
    migrate :up unless ActiveRecord::Base.connection.column_exists?(:oauth_retired_refresh_tokens, :refresh_token_digest)
    [ PreviousAccessToken, Identity::AccessToken, Oauth::Client, Oauth::RetiredRefreshToken ].each(&:reset_column_information)
    PreviousAccessToken.where(description: "Cached before the migration").delete_all
  end

  test "a process that cached identity_access_tokens' columns before it creates tokens after it" do
    migrate :up

    assert_difference -> { PreviousAccessToken.count }, 2 do
      PreviousAccessToken.create! identity_id: identities(:david).id, permission: "write", description: "Cached before the migration"
      identities(:david).access_tokens.create! description: "Cached before the migration"
    end
  end

  private
    def migrate(direction)
      DropPlaintextOauthCredentials.new.tap { |migration| migration.verbose = false }.migrate(direction)
    end
end
