#!/usr/bin/env ruby

require_relative "../config/environment"
require "pathname"
require "uri"
require "base64"
require "json"

class FixActiveStorage
  def initialize
    @mapping = {}
  end

  def ingest_blob_keys(db_path)
    models = Models.new(db_path)

    @mapping[models.accounts.sole.external_account_id.to_s] = models.blobs.all.index_by(&:id)
  end

  def perform
    ActionText::RichText.all.where("body LIKE '%/rails/active_storage/%'").find_each do |rich_text|
      next unless rich_text.body

      rich_text.body.send(:attachment_nodes).each do |node|
        sgid = node["sgid"]
        url = node["url"]
        next if url.blank? || sgid.blank?

        sgid = SignedGlobalID.parse(node["sgid"], for: ActionText::Attachable::LOCATOR_NAME)
        old_blob = @mapping.dig(sgid.params[:tenant], sgid.model_id)
        raise "Blob not found for sgid #{sgid}" unless old_blob

        new_blob = ActiveStorage::Blob.find_by!(key: old_blob.key)
        # node["sgid"] = new_blob.attachable_sgid
      end

      # rich_text.save!
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
    @blobs ||= Class.new(application_record) do
      self.table_name = "active_storage_blobs"
    end
  end

  def attachments
    @attachments ||= Class.new(application_record) do
      self.table_name = "active_storage_attachments"
    end
  end
end

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
