# Reindex cards and comments that may be missing from the search index.
#
# The data import path (Account::DataTransfer) uses insert_all! which bypasses
# ActiveRecord callbacks, so imported cards and comments never get search records
# created. This script reindexes cards and comments created before a cutoff date.
#
# Usage:
#   bin/rails runner script/maintenance/reindex_stale_search_records.rb              # default cutoff: 2025-11-13
#   bin/rails runner script/maintenance/reindex_stale_search_records.rb 2026-01-01   # custom cutoff

cutoff = Date.parse(ARGV[0] || "2025-11-13")

puts "Reindexing cards and comments created before #{cutoff}..."

cards = Card.published.where("created_at < ?", cutoff).includes(:rich_text_description)
card_count = cards.count
puts "Found #{card_count} cards to reindex"

reindexed_cards = 0
cards.find_each do |card|
  card.reindex
  reindexed_cards += 1
  print "\rCards: #{reindexed_cards}/#{card_count}" if reindexed_cards % 100 == 0
end
puts "\rCards: #{reindexed_cards}/#{card_count}"

comments = Comment.joins(:card).merge(Card.published).where("comments.created_at < ?", cutoff).includes(:rich_text_body, :card)
comment_count = comments.count
puts "Found #{comment_count} comments to reindex"

reindexed_comments = 0
comments.find_each do |comment|
  comment.reindex
  reindexed_comments += 1
  print "\rComments: #{reindexed_comments}/#{comment_count}" if reindexed_comments % 100 == 0
end
puts "\rComments: #{reindexed_comments}/#{comment_count}"

puts "Done! Reindexed #{reindexed_cards} cards and #{reindexed_comments} comments."
