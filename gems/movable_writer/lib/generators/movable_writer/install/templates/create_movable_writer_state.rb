# frozen_string_literal: true

class CreateMovableWriterState < ActiveRecord::Migration[8.0]
  create_table "movable_writer_states" do |t|
    t.string :writer
    t.datetime :updated_at, null: false
  end
end
