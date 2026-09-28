#!/usr/bin/env ruby

require_relative "../../config/environment"

total_reindexed = 0

Account.find_each do |account|
  # Reindexing removes rather than writes here: has_search's :if guard fails for a
  # draft card, and for its comments.
  draft_card_ids = Card.where(account_id: account.id, status: "drafted").pluck(:id)

  if draft_card_ids.any?
    count = 0

    Comment.where(card_id: draft_card_ids).find_each do |comment|
      comment.reindex
      count += 1
    end

    Card.where(id: draft_card_ids).find_each do |card|
      card.reindex
      count += 1
    end

    puts "#{account.name}: reindexed #{count} records for draft cards"
    total_reindexed += count
  end
end

puts "Migration completed! Total reindexed: #{total_reindexed}"
