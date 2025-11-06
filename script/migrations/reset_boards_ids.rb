#!/usr/bin/env ruby

require_relative "../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  id_mapping = {}

  puts "Processing tenant: #{tenant}"

  # Disable foreign key constraints
  ApplicationRecord.connection.execute("PRAGMA foreign_keys = OFF;")

  begin
    # Get all boards ordered by ID
    boards = Board.order(:id).to_a

    # Create mapping of old IDs to new IDs
    boards.each_with_index do |board, index|
      id_mapping[board.id] = index + 1
    end

    # Update foreign keys in related tables
    puts "Updating foreign keys in related tables..."

    # Update accesses table
    Access.where.not(board_id: nil).find_each do |access|
      if id_mapping[access.board_id]
        access.update_column(:board_id, id_mapping[access.board_id])
      end
    end

    # Update cards table
    Card.where.not(board_id: nil).find_each do |card|
      if id_mapping[card.board_id]
        card.update_column(:board_id, id_mapping[card.board_id])
      end
    end

    # Update boards_filters table (join table)
    ApplicationRecord.connection.execute("SELECT board_id FROM boards_filters").each do |row|
      old_id = row[0]
      if id_mapping[old_id]
        ApplicationRecord.connection.execute("UPDATE boards_filters SET board_id = #{id_mapping[old_id]} WHERE board_id = #{old_id}")
      end
    end

    # Update events table
    Event.where.not(board_id: nil).find_each do |event|
      if id_mapping[event.board_id]
        event.update_column(:board_id, id_mapping[event.board_id])
      end
    end

    # Update events table (polymorphic relationship)
    Event.where(eventable_type: "Board").find_each do |event|
      if id_mapping[event.eventable_id]
        event.update_column(:eventable_id, id_mapping[event.eventable_id])
      end
    end

    # Update mentions table (polymorphic relationship)
    Mention.where(source_type: "Board").find_each do |mention|
      if id_mapping[mention.source_id]
        mention.update_column(:source_id, id_mapping[mention.source_id])
      end
    end

    # Update notifications table (polymorphic relationship)
    Notification.where(source_type: "Board").find_each do |notification|
      if id_mapping[notification.source_id]
        notification.update_column(:source_id, id_mapping[notification.source_id])
      end
    end

    # Update action_text_markdowns table (polymorphic relationship)
    ActionText::RichText.where(record_type: "Board").find_each do |rich_text|
      if id_mapping[rich_text.record_id]
        rich_text.update_column(:record_id, id_mapping[rich_text.record_id])
      end
    end

    # Update active_storage_attachments table (polymorphic relationship)
    ActiveStorage::Attachment.where(record_type: "Board").find_each do |attachment|
      if id_mapping[attachment.record_id]
        attachment.update_column(:record_id, id_mapping[attachment.record_id])
      end
    end

    # Reset the boards table IDs
    puts "Resetting board IDs..."
    boards.each do |board|
      new_id = id_mapping[board.id]
      # Use direct SQL to update the ID to avoid ActiveRecord validations
      ApplicationRecord.connection.execute("UPDATE boards SET id = #{new_id} WHERE id = #{board.id}")
    end

    # Reset the SQLite sequence for the boards table
    ApplicationRecord.connection.execute("DELETE FROM sqlite_sequence WHERE name = 'boards'")
    max_id = Board.maximum(:id) || 0
    ApplicationRecord.connection.execute("INSERT INTO sqlite_sequence (name, seq) VALUES ('boards', #{max_id})")

    puts "Board IDs have been reset successfully!"
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace
  ensure
    # Re-enable foreign key constraints
    ApplicationRecord.connection.execute("PRAGMA foreign_keys = ON;")
  end

  # Update links in card descriptions and comment bodies
  Card.find_each do |card|
    description = card.description.content.dup

    description.gsub!(/boards\/(\d+)\//) do |match|
      old_id = $1.to_i
      new_id = id_mapping[old_id]

      new_id ? "boards/#{new_id}/" : match
    end

    if description != card.description.content
      puts "Updating links in card #{card.id}"
      card.update!(description: description)
    end
  end

  Comment.find_each do |comment|
    body = comment.body.content.dup

    body.gsub!(/boards\/(\d+)\//) do |match|
      old_id = $1.to_i
      new_id = id_mapping[old_id]
      new_id ? "boards/#{new_id}/" : match
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
