#!/usr/bin/env ruby

require_relative "../config/environment"
require "pathname"
require "uri"
require "base64"
require "json"

class FixActiveStorage
  attr_reader :skipped, :processed

  def initialize(scope = nil)
    @scope = scope || ActionText::RichText.all.where("body LIKE '%/rails/active_storage/%'")
    @mapping = {}
    @skipped = 0
    @processed = 0
  end

  def ingest_blob_keys(db_path)
    models = Models.new(db_path)

    @mapping[models.accounts.sole.external_account_id.to_s] = models.blobs.all.index_by(&:id)
  end

  def perform
    scope.find_each do |rich_text|
      next unless rich_text.body

      rich_text.body.send(:attachment_nodes).each do |node|
        sgid = node["sgid"]
        url = node["url"]
        next if url.blank? || sgid.blank?

        sgid = SignedGlobalID.parse(node["sgid"], for: ActionText::Attachable::LOCATOR_NAME)
        old_blob = @mapping.dig(sgid.params[:tenant], sgid.model_id.to_i)

        # There are some old files that got lost in a previous migration
        unless old_blob
          @skipped += 1
          next
        end

        new_blob = ActiveStorage::Blob.find_by(key: old_blob.key)

        unless new_blob
          new_blob = ActiveStorage::Blob.create!(
            account_id: rich_text.account_id,
            byte_size: old_blob.byte_size,
            checksum: old_blob.checksum,
            content_type: old_blob.content_type,
            created_at: old_blob.created_at,
            filename: old_blob.filename,
            key: old_blob.key,
            metadata: old_blob.metadata,
            service_name: old_blob.service_name
          )

          ActiveStorage::Attachment.create!(
            account_id: rich_text.account_id,
            blob_id: new_blob.id,
            created_at: old_blob.created_at,
            name: "embeds",
            record: rich_text
          )
        end

        node["sgid"] = new_blob.attachable_sgid

        @processed += 1
      end

      rich_text.save!
    end
  end
end

class Models
  attr_reader :application_record

  def initialize(db_path)
    const_name = "ImportBase#{db_path.hash.abs}"

    if self.class.const_defined?(const_name)
      @application_record = self.class.const_get(const_name)
    else
      @application_record = Class.new(ActiveRecord::Base) do
        self.abstract_class = true

        def self.models
          const_get("MODELS")
        end

        delegate :models, to: :class
      end
      self.class.const_set(const_name, @application_record)
    end

    @application_record.establish_connection adapter: "sqlite3", database: db_path
    @application_record.const_set("MODELS", self)
  end

  def accounts
    @accounts ||= Class.new(application_record) do
      self.table_name = "accounts"
    end
  end

  def blobs
    models = self
    @blobs ||= Class.new(application_record) do
      self.table_name = "active_storage_blobs"

      def attachments
        models.attachments.where(blob_id: id)
      end
    end
  end

  def attachments
    @attachments ||= Class.new(application_record) do
      self.table_name = "active_storage_attachments"
    end
  end
end

scope = Card.find!(xxx).description
# tenanted_db_paths = ARGV
tenanted_db_paths = Dir[Rails.root.join("storage/tenants/production/*/db/main.sqlite3")]

if tenanted_db_paths.empty?
  $stderr.puts "Error: at least one tenanted database path is required"
  $stderr.puts
  $stderr.puts parser
  exit 1
end

fix = FixActiveStorage.new

tenanted_db_paths.each_with_index do |db_path, _index|
  fix.ingest_blob_keys(db_path)
end

fix.perform
