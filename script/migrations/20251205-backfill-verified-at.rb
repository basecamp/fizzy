#!/usr/bin/env ruby

require_relative "../../config/environment"

BACKFILL_TIMESTAMP = Time.parse("2025-12-02 12:00:00 UTC")

def collect_verified_user_ids
  verified_ids = Set.new

  # Owners (they created the account)
  verified_ids.merge(User.where(role: :owner).pluck(:id))
  puts "After owners: #{verified_ids.size} users"

  # Card creators
  verified_ids.merge(Card.distinct.pluck(:creator_id).compact)
  puts "After card creators: #{verified_ids.size} users"

  # Comment creators
  verified_ids.merge(Comment.distinct.pluck(:creator_id).compact)
  puts "After comment creators: #{verified_ids.size} users"

  # Board creators
  verified_ids.merge(Board.distinct.pluck(:creator_id).compact)
  puts "After board creators: #{verified_ids.size} users"

  # Event creators
  verified_ids.merge(Event.distinct.pluck(:creator_id).compact)
  puts "After event creators: #{verified_ids.size} users"

  # Assigners (not assignees - they could be assigned without logging in)
  verified_ids.merge(Assignment.distinct.pluck(:assigner_id).compact)
  puts "After assigners: #{verified_ids.size} users"

  # Manual closers (user_id is nil for automatic closures)
  verified_ids.merge(Closure.where.not(user_id: nil).distinct.pluck(:user_id).compact)
  puts "After closers: #{verified_ids.size} users"

  # Manual postponers (user_id is nil for automatic entropy postponements)
  verified_ids.merge(Card::NotNow.where.not(user_id: nil).distinct.pluck(:user_id).compact)
  puts "After postponers: #{verified_ids.size} users"

  # Reactors
  verified_ids.merge(Reaction.distinct.pluck(:reacter_id).compact)
  puts "After reactors: #{verified_ids.size} users"

  # Filter creators
  verified_ids.merge(Filter.distinct.pluck(:creator_id).compact)
  puts "After filter creators: #{verified_ids.size} users"

  # Pinners
  verified_ids.merge(Pin.distinct.pluck(:user_id).compact)
  puts "After pinners: #{verified_ids.size} users"

  # Board accessors (accessed_at is touched when viewing boards)
  verified_ids.merge(Access.where.not(accessed_at: nil).distinct.pluck(:user_id).compact)
  puts "After board accessors: #{verified_ids.size} users"

  # Export requesters
  verified_ids.merge(Account::Export.distinct.pluck(:user_id).compact)
  puts "After export requesters: #{verified_ids.size} users"

  # Push subscribers
  verified_ids.merge(Push::Subscription.distinct.pluck(:user_id).compact)
  puts "After push subscribers: #{verified_ids.size} users"

  # Users who completed setup (name != email)
  verified_ids.merge(
    User.joins(:identity)
        .where.not("users.name = identities.email_address")
        .pluck(:id)
  )
  puts "After setup completers: #{verified_ids.size} users"

  # Users whose identity has at least one session
  verified_ids.merge(
    User.where(identity_id: Session.distinct.select(:identity_id)).pluck(:id)
  )
  puts "After identity sessions: #{verified_ids.size} users"

  verified_ids
end

puts "Collecting verified user IDs..."
verified_user_ids = collect_verified_user_ids

puts "\nFiltering to unverified users only..."
users_to_update = User.where(id: verified_user_ids.to_a)
                      .where(verified_at: nil)
                      .where(active: true)
                      .where.not(identity_id: nil)
                      .where.not(role: :system)

update_count = users_to_update.count
puts "Found #{update_count} users to backfill"

# Report remaining unverified users (before update)
remaining_before = User.where(verified_at: nil, active: true)
                       .where.not(identity_id: nil)
                       .where.not(role: :system)
                       .count
remaining_after = remaining_before - update_count
puts "\nCurrently unverified active users: #{remaining_before}"
puts "After backfill, remaining unverified: #{remaining_after}"
puts "These users will need to verify on next login."

if update_count > 0
  puts "\nBackfilling verified_at..."
  updated = users_to_update.update_all(verified_at: BACKFILL_TIMESTAMP)
  puts "Updated #{updated} users"
end

puts "\nDone!"
