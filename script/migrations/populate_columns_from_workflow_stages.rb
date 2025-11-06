#!/usr/bin/env ruby

require_relative "../../config/environment"

class Card
  has_one :engagement, dependent: :destroy, class_name: "Card::Engagement"

  def doing?
    open? && published? && engagement&.status == "doing"
  end

  def on_deck?
    open? && published? && engagement&.status == "on_deck"
  end

  def considering?
    open? && published? && engagement.blank?
  end
end

ApplicationRecord.with_each_tenant do |tenant|
  puts "Processing tenant: #{tenant}"

  Column.destroy_all

  Board.find_each do |board|
    next unless board.workflow.present?

    # Map to track stage_id -> column
    columns_by_stage = {}

    # Create columns from workflow stages
    board.workflow.stages.find_each do |stage|
      column = board.columns.create!(
        name: stage.name,
        color: stage.color || Card::Colored::COLORS.first
      )
      columns_by_stage[stage] = column
      puts "Created column '#{column.name}' for board '#{board.name}'"
    end

    # Associate cards with their corresponding columns based on stages
    board.cards.includes(:stage).find_each do |card|
      next if !card.doing? || card.stage.blank?

      unless card.stage.workflow.boards.include?(board)
        puts "Corrupt data: the card with id #{card.id} has the stage #{card.stage.name} with id #{card.stage.id} that belongs to a workflow not asociated ot its board"
        next
      end

      stage = columns_by_stage[card.stage]
      card.update!(column: stage)
      puts "Associated card ##{card.id} with column '#{stage.name}'"
    end
  end
end

puts "Migration completed!"
