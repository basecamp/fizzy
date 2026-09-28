namespace :search do
  desc "Reindex all cards and comments in the search index"
  task reindex: :environment do
    puts "Clearing search records..."
    # Raw deletes rather than a per-account remove: a row whose account is gone has no account to visit.
    if ActiveRecord::Base.connection.adapter_name == "SQLite"
      ActiveRecord::Base.connection.execute("DELETE FROM search_records")
      ActiveRecord::Base.connection.execute("DELETE FROM search_records_fts")
    else
      ActiveSearch::StoreAdapters::MysqlSharded::SHARD_COUNT.times do |shard_id|
        ActiveRecord::Base.connection.execute("DELETE FROM search_records_#{shard_id}")
      end
    end

    puts "Reindexing cards..."
    Card.includes(:rich_text_description).find_each(&:reindex)

    puts "Reindexing comments..."
    Comment.includes(:rich_text_body, :card).find_each(&:reindex)

    puts "Done! Reindexed #{Card.count} cards and #{Comment.count} comments."
  end
end
