# Fix comment events that are on the wrong board after a card move.
#
# See https://github.com/basecamp/fizzy/pull/2486
#
# Usage:
#   bin/rails runner script/migrations/20260204-fix-misplaced-comment-events.rb           # dry run
#   bin/rails runner script/migrations/20260204-fix-misplaced-comment-events.rb --fix     # actually fix
#
dry_run = !ARGV.include?("--fix")

puts dry_run ? "DRY RUN - no changes will be made\n\n" : "FIXING misplaced events\n\n"

misplaced_events = Event
  .where(eventable_type: "Comment")
  .joins("INNER JOIN comments ON comments.id = events.eventable_id")
  .joins("INNER JOIN cards ON cards.id = comments.card_id")
  .where("events.board_id != cards.board_id")

total = misplaced_events.count
puts "Found #{total} misplaced comment events\n\n"

if total.zero?
  puts "Nothing to fix!"
  exit
end

fixed = 0
skipped = 0

misplaced_events.find_each.with_index do |event, index|
  comment = event.eventable
  card = comment&.card
  old_board = event.board
  new_board = card&.board

  puts "[#{index + 1}/#{total}] Event #{event.id}"

  if card.nil? || new_board.nil?
    puts "  Skipping - orphaned data (comment or card deleted)"
    skipped += 1
    puts
    next
  end

  puts "  Card ##{card.number}: #{card.title.truncate(40)}"
  puts "  Moving from board '#{old_board&.name || 'nil'}' to '#{new_board.name}'"

  if dry_run
    puts "  (skipped - dry run)"
  else
    event.update!(board: new_board)
    fixed += 1
    puts "  Fixed!"
  end

  puts
end

puts "Done. #{dry_run ? "Run with --fix to apply changes." : "Fixed #{fixed} events."} (#{skipped} skipped)"
