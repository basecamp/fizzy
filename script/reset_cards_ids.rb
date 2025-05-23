#!/usr/bin/env ruby

require_relative "../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  id_mapping = {}

  puts "Processing tenant: #{tenant}"

  # Disable foreign key constraints
  ApplicationRecord.connection.execute("PRAGMA foreign_keys = OFF;")

  begin
    # Get all cards ordered by ID
    cards = Card.order(:id).to_a

    # Create mapping of old IDs to new IDs
    cards.each_with_index do |card, index|
      id_mapping[card.id] = index + 1
    end

    # Update foreign keys in related tables
    puts "Updating foreign keys in related tables..."

    # Update assignments table
    Assignment.where.not(card_id: nil).find_each do |assignment|
      if id_mapping[assignment.card_id]
        assignment.update_column(:card_id, id_mapping[assignment.card_id])
      end
    end

    # Update card_engagements table
    Card::Engagement.where.not(card_id: nil).find_each do |engagement|
      if id_mapping[engagement.card_id]
        engagement.update_column(:card_id, id_mapping[engagement.card_id])
      end
    end

    # Update card_goldnesses table
    Card::Goldness.where.not(card_id: nil).find_each do |goldness|
      if id_mapping[goldness.card_id]
        goldness.update_column(:card_id, id_mapping[goldness.card_id])
      end
    end

    # Update closures table
    Closure.where.not(card_id: nil).find_each do |closure|
      if id_mapping[closure.card_id]
        closure.update_column(:card_id, id_mapping[closure.card_id])
      end
    end

    # Update comments table
    Comment.where.not(card_id: nil).find_each do |comment|
      if id_mapping[comment.card_id]
        comment.update_column(:card_id, id_mapping[comment.card_id])
      end
    end

    # Update pins table
    Pin.where.not(card_id: nil).find_each do |pin|
      if id_mapping[pin.card_id]
        pin.update_column(:card_id, id_mapping[pin.card_id])
      end
    end

    # Update taggings table
    Tagging.where.not(card_id: nil).find_each do |tagging|
      if id_mapping[tagging.card_id]
        tagging.update_column(:card_id, id_mapping[tagging.card_id])
      end
    end

    # Update watches table
    Watch.where.not(card_id: nil).find_each do |watch|
      if id_mapping[watch.card_id]
        watch.update_column(:card_id, id_mapping[watch.card_id])
      end
    end

    # Update events table (polymorphic relationship)
    Event.where(eventable_type: "Card").find_each do |event|
      if id_mapping[event.eventable_id]
        event.update_column(:eventable_id, id_mapping[event.eventable_id])
      end
    end

    # Update mentions table (polymorphic relationship)
    Mention.where(source_type: "Card").find_each do |mention|
      if id_mapping[mention.source_id]
        mention.update_column(:source_id, id_mapping[mention.source_id])
      end
    end

    # Update notifications table (polymorphic relationship)
    Notification.where(source_type: "Card").find_each do |notification|
      if id_mapping[notification.source_id]
        notification.update_column(:source_id, id_mapping[notification.source_id])
      end
    end

    # Update action_text_markdowns table (polymorphic relationship)
    ActionText::RichText.where(record_type: "Card").find_each do |rich_text|
      if id_mapping[rich_text.record_id]
        rich_text.update_column(:record_id, id_mapping[rich_text.record_id])
      end
    end

    # Reset the cards table IDs
    puts "Resetting card IDs..."
    cards.each do |card|
      new_id = id_mapping[card.id]
      # Use direct SQL to update the ID to avoid ActiveRecord validations
      ApplicationRecord.connection.execute("UPDATE cards SET id = #{new_id} WHERE id = #{card.id}")
    end

    # Reset the SQLite sequence for the cards table
    ApplicationRecord.connection.execute("DELETE FROM sqlite_sequence WHERE name = 'cards'")
    max_id = Card.maximum(:id) || 0
    ApplicationRecord.connection.execute("INSERT INTO sqlite_sequence (name, seq) VALUES ('cards', #{max_id})")

    puts "Card IDs have been reset successfully!"
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace
  ensure
    # Re-enable foreign key constraints
    ApplicationRecord.connection.execute("PRAGMA foreign_keys = ON;")
  end

  Card.find_each do |card|
    description = card.description.content.dup

    description.gsub!(/cards\/(\d+)\)/) do |match|
      old_id = $1.to_i
      new_id = id_mapping[old_id]

      new_id ? "cards/#{new_id})" : match
    end

    if description != card.description.content
      puts "Updating links in card #{card.id}"
      card.update!(description: description)
    end
  end

  Comment.find_each do |comment|
    body = comment.body.content.dup

    body.gsub!(/cards\/(\d+)\)/) do |match|
      old_id = $1.to_i
      new_id = id_mapping[old_id]
      new_id ? "cards/#{new_id})" : match
    end

    if body != comment.body.content
      puts "Updating links in comment #{comment.id}"
      comment.update!(body: body)
    end
  end

  # Output the mapping of old IDs to new IDs
  puts "\nMapping of old IDs to new IDs:"
  puts id_mapping.inspect
end
