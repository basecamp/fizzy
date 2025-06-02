# frozen_string_literal: true

require "rails/generators/active_record/migration"

module MovableWriter
  class InstallGenerator < Rails::Generators::Base
    include ActiveRecord::Generators::Migration

    source_root File.expand_path("templates", __dir__)

    def create_migration_file
      migration_template "create_movable_writer_state.rb", "db/migrate/create_movable_writer_state.rb"
    end
  end
end
