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
    @mapping.merge!(Models.new(db_path).blobs.all.index_by(&:key))
  end

  def perform
    skipped = 0
    ActionText::RichText.all.where("body LIKE '%/rails/active_storage/%'").find_each do |rich_text|
      next unless rich_text.body

      blobs = rich_text.embeds.map(&:blob)

      rich_text.body.send(:attachment_nodes).each do |node|
        url = node["url"]
        next unless url

        url_encoded_filename = url.split("/").last
        filename = URI.decode_www_form_component(url_encoded_filename)

        counter += 1
        blob = if blobs.size == 1
          blobs
        else
          blobs.select { |b| b.filename == filename }
        end
        raise "Multiple blobs with filename #{filename}" if blob.size > 1
        blob = blob.first

        if blob
          # node["sgid"] = blob.attachable_sgid
        else
          skipped += 1
        end
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

tenanted_db_paths = ARGV

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
