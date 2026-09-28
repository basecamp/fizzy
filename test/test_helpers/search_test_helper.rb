module SearchTestHelper
  extend ActiveSupport::Concern

  included do
    self.use_transactional_tests = false

    setup :setup_search_test
    teardown :teardown_search_test
  end

  def setup_search_test
    clear_search_records
    Account.find_by(name: "Search Test")&.destroy
    Identity.find_by(email_address: "test@example.com")&.destroy

    @account = Account.create!(name: "Search Test", external_account_id: ActiveRecord::FixtureSet.identify("search_test"))
    Current.account = @account
    @identity = Identity.create!(email_address: "test@example.com")
    @user = User.create!(name: "Test User", account: @account, identity: @identity)
    Current.user = @user
    @board = Board.create!(name: "Test Board", account: @account, creator: @user)
  end

  def teardown_search_test
    clear_search_records
    Account.find_by(name: "Search Test")&.destroy
    Identity.find_by(email_address: "test@example.com")&.destroy
  end
end
