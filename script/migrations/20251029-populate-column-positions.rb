#!/usr/bin/env ruby

require_relative "../../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  puts "Processing tenant: #{tenant}"

  Board.find_each do |board|
    puts "  Processing board: #{board.name} (ID: #{board.id})"

    columns = board.columns.order(:id)

    columns.each_with_index do |column, index|
      column.update_column(:position, index)
      puts "    Set position #{index} for column '#{column.name}' (ID: #{column.id})"
    end
  end
end

puts "Migration completed!"
