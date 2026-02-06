module ActiveRecordTasksDatabaseTasksExtension
  extend ActiveSupport::Concern

  class_methods do
    # proposed upstream in https://github.com/rails/rails/pull/56290
    def schema_dump_path(db_config, format = db_config.schema_format)
      return ENV["SCHEMA"] if ENV["SCHEMA"]

      filename = db_config.schema_dump(format)
      return unless filename

      if Pathname.new(filename).absolute?
        filename
      else
        super
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Tasks::DatabaseTasks.include(ActiveRecordTasksDatabaseTasksExtension)
end
