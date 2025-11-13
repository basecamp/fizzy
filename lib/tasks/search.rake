namespace :search do
  desc "Reindex all cards and comments in the search index"
  task reindex: :environment do
    puts "Clearing search records..."
    Search::Record::SHARD_COUNT.times do |shard_id|
      ActiveRecord::Base.connection.execute("DELETE FROM search_records_#{shard_id}")
    end

    puts "Reindexing cards..."
    Card.find_each do |card|
      card.reindex
    end

    puts "Reindexing comments..."
    Comment.find_each do |comment|
      comment.reindex
    end

    puts "Done! Reindexed #{Card.count} cards and #{Comment.count} comments."
  end
end
