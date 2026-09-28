require "test_helper"

class Search::ShardingTest < ActiveSupport::TestCase
  include SearchTestHelper

  Tenant = Struct.new(:account, :user, :board)

  teardown do
    @tenants.to_a.each do |tenant|
      search_index.remove_by_filter(account_id: tenant.account.id)
      tenant.user.identity.destroy
      tenant.account.destroy
    end
  end

  test "an account sharing a shard with another reads only its own rows" do
    neighbour = tenant_routing_to(search_shard_for(@account.id).table_name)

    assert_equal search_shard_for(@account.id).table_name, search_shard_for(neighbour.account.id).table_name,
      "the two accounts must hash to one table, or this passes without isolating anything"
    assert_not_equal @account.id, neighbour.account.id

    mine = card_for(tenant, title: "kestrelsierra mine")
    theirs = card_for(neighbour, title: "kestrelsierra theirs")

    assert_equal 2, search_shard_for(@account.id).where(account_id: [ @account.id, neighbour.account.id ]).count,
      "both rows must sit in that one table, or neither search had anything to exclude"

    assert_equal [ mine ], @user.search("kestrelsierra").results.to_a
    assert_equal [ theirs ], neighbour.user.search("kestrelsierra").results.to_a

    # User#search also filters by board, so these carry the account clause on its own.
    assert_equal 1, search_index.search("kestrelsierra").filter(account_id: @account.id).results.total
    assert_equal 1, search_index.search("kestrelsierra").filter(account_id: neighbour.account.id).results.total
  end

  test "every shard answers a full-text match against its own index" do
    skip "SQLite keeps one unsharded FTS table" unless sharded_search?

    tenants = shard_tables.map { |table| tenant_routing_to(table) }
    assert_equal shard_tables, tenants.map { |tenant| search_shard_for(tenant.account.id).table_name }

    tenants.each { |tenant| card_for(tenant, title: "kestreltango card") }

    tenants.each do |tenant|
      assert_equal 1, search_index.search("kestreltango").filter(account_id: tenant.account.id).results.total,
        "no match on #{search_shard_for(tenant.account.id).table_name}"
    end
  end

  test "the schema holds a table for every shard the adapter routes to" do
    skip "SQLite keeps one unsharded FTS table" unless sharded_search?

    assert_equal shard_tables.sort, Search::Record.connection.tables.grep(/\Asearch_records_\d+\z/).sort
  end

  test "a document stores the account token its shard's fulltext index matches on" do
    skip "SQLite has no account_key column" unless sharded_search?

    card = card_for(tenant, title: "kestrelvictor card")

    assert_equal "account#{@account.id}", find_search_record(@account.id, type: "Card", id: card.id).account_key
  end

  private
    def shard_tables
      (0...ActiveSearch::StoreAdapters::MysqlSharded::SHARD_COUNT).map { |shard| "search_records_#{shard}" }
    end

    def tenant
      Tenant.new(@account, @user, @board)
    end

    def tenant_routing_to(table)
      account_id = ActiveRecord::Type::Uuid.generate
      account_id = ActiveRecord::Type::Uuid.generate until search_shard_for(account_id).table_name == table

      build_tenant(account_id).tap { |built| (@tenants ||= []) << built }
    end

    def build_tenant(account_id)
      account = Account.create!(id: account_id, name: "Shard #{account_id}", external_account_id: SecureRandom.random_number(10**12))
      identity = Identity.create!(email_address: "#{account_id}@example.com")

      with_current(account, nil) do
        user = User.create!(name: "Shard User", account: account, identity: identity)
        with_current(account, user) { Tenant.new(account, user, Board.create!(name: "Shard Board", account: account, creator: user)) }
      end
    end

    # Cards raise without a Current.user: their event records default a creator from it.
    def card_for(tenant, title:)
      with_current(tenant.account, tenant.user) do
        tenant.board.cards.create!(title: title, creator: tenant.user, status: "published")
      end
    end

    def with_current(account, user)
      previous = [ Current.account, Current.user ]
      Current.account, Current.user = account, user
      yield
    ensure
      Current.account, Current.user = previous
    end
end
