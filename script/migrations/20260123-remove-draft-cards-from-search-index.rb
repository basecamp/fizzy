#!/usr/bin/env ruby

require_relative "../../config/environment"

total_deleted = 0

Account.find_each do |account|
  search_record_class = Search::Record.for(account.id)

  # Find search records for draft cards (both Card and Comment searchables)
  draft_card_ids = Card.where(account_id: account.id, status: "drafted").pluck(:id)

  if draft_card_ids.any?
    count = search_record_class.where(card_id: draft_card_ids).delete_all
    if count > 0
      puts "#{account.name}: deleted #{count} search records for draft cards"
      total_deleted += count
    end
  end
end

puts "Migration completed! Total deleted: #{total_deleted}"
