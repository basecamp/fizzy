module Search
  def self.table_name_prefix
    "search_"
  end

  def self.results(query:, user:)
    Record.for_account(user.account_id).search(query: Query.wrap(query), user: user)
  end
end
