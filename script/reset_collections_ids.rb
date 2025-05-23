#!/usr/bin/env ruby

require_relative "../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  id_mapping = {}

  puts "Processing tenant: #{tenant}"

  # Disable foreign key constraints
  ApplicationRecord.connection.execute("PRAGMA foreign_keys = OFF;")

  begin
    # Get all collections ordered by ID
    collections = Collection.order(:id).to_a

    # Create mapping of old IDs to new IDs
    collections.each_with_index do |collection, index|
      id_mapping[collection.id] = index + 1
    end

    # Update foreign keys in related tables
    puts "Updating foreign keys in related tables..."

    # Update accesses table
    Access.where.not(collection_id: nil).find_each do |access|
      if id_mapping[access.collection_id]
        access.update_column(:collection_id, id_mapping[access.collection_id])
      end
    end

    # Update cards table
    Card.where.not(collection_id: nil).find_each do |card|
      if id_mapping[card.collection_id]
        card.update_column(:collection_id, id_mapping[card.collection_id])
      end
    end

    # Update collections_filters table (join table)
    ApplicationRecord.connection.execute("SELECT collection_id FROM collections_filters").each do |row|
      old_id = row[0]
      if id_mapping[old_id]
        ApplicationRecord.connection.execute("UPDATE collections_filters SET collection_id = #{id_mapping[old_id]} WHERE collection_id = #{old_id}")
      end
    end

    # Update events table
    Event.where.not(collection_id: nil).find_each do |event|
      if id_mapping[event.collection_id]
        event.update_column(:collection_id, id_mapping[event.collection_id])
      end
    end

    # Update events table (polymorphic relationship)
    Event.where(eventable_type: "Collection").find_each do |event|
      if id_mapping[event.eventable_id]
        event.update_column(:eventable_id, id_mapping[event.eventable_id])
      end
    end

    # Update mentions table (polymorphic relationship)
    Mention.where(source_type: "Collection").find_each do |mention|
      if id_mapping[mention.source_id]
        mention.update_column(:source_id, id_mapping[mention.source_id])
      end
    end

    # Update notifications table (polymorphic relationship)
    Notification.where(source_type: "Collection").find_each do |notification|
      if id_mapping[notification.source_id]
        notification.update_column(:source_id, id_mapping[notification.source_id])
      end
    end

    # Update action_text_markdowns table (polymorphic relationship)
    ActionText::RichText.where(record_type: "Collection").find_each do |rich_text|
      if id_mapping[rich_text.record_id]
        rich_text.update_column(:record_id, id_mapping[rich_text.record_id])
      end
    end

    # Update active_storage_attachments table (polymorphic relationship)
    ActiveStorage::Attachment.where(record_type: "Collection").find_each do |attachment|
      if id_mapping[attachment.record_id]
        attachment.update_column(:record_id, id_mapping[attachment.record_id])
      end
    end

    # Reset the collections table IDs
    puts "Resetting collection IDs..."
    collections.each do |collection|
      new_id = id_mapping[collection.id]
      # Use direct SQL to update the ID to avoid ActiveRecord validations
      ApplicationRecord.connection.execute("UPDATE collections SET id = #{new_id} WHERE id = #{collection.id}")
    end

    # Reset the SQLite sequence for the collections table
    ApplicationRecord.connection.execute("DELETE FROM sqlite_sequence WHERE name = 'collections'")
    max_id = Collection.maximum(:id) || 0
    ApplicationRecord.connection.execute("INSERT INTO sqlite_sequence (name, seq) VALUES ('collections', #{max_id})")

    puts "Collection IDs have been reset successfully!"
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

    description.gsub!(/collections\/(\d+)\//) do |match|
      old_id = $1.to_i
      new_id = id_mapping[old_id]

      new_id ? "collections/#{new_id}/" : match
    end

    if description != card.description.content
      puts "Updating links in card #{card.id}"
      card.update!(description: description)
    end
  end

  Comment.find_each do |comment|
    body = comment.body.content.dup

    body.gsub!(/collections\/(\d+)\//) do |match|
      old_id = $1.to_i
      new_id = id_mapping[old_id]
      new_id ? "collections/#{new_id}/" : match
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
