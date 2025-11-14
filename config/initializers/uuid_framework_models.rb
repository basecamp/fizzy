# Inject UUID primary key support into Rails framework models
Rails.application.config.to_prepare do
  ActionText::RichText.attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }
  ActionText::RichText.belongs_to :account, default: -> { record.account }

  ActiveStorage::Attachment.attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }
  ActiveStorage::Attachment.belongs_to :account, default: -> { record.account }

  ActiveStorage::Blob.attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }
  ActiveStorage::Blob.belongs_to :account, default: -> { Current.account }

  ActiveStorage::VariantRecord.attribute :id, :uuid, default: -> { ActiveRecord::Type::Uuid.generate }
  ActiveStorage::VariantRecord.belongs_to :account, default: -> { blob.account }
end
