class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # SQLite doesn't use separate replica databases
  if ENV.fetch("DATABASE_ADAPTER", "mysql") == "sqlite"
    connects_to database: { writing: :primary, reading: :primary }
  else
    connects_to database: { writing: :primary, reading: :replica }
  end

  attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }
end
