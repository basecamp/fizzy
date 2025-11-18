#!/usr/bin/env ruby

require_relative "../config/environment"
require "pathname"
require "uri"
require "base64"
require "json"

class FixActiveStorage
  attr_reader :skipped, :processed, :scope

  def initialize(scope = nil)
    @scope = scope || ActionText::RichText.all.where("body LIKE '%/rails/active_storage/%'")
    @mapping = {}

    @skipped = 0
    @processed = 0

    @users = {}
    @memberships = {}
    @attachments = {}
    @identities = {}
  end

  def ingest_blob_keys(db_path)
    models = Models.new(db_path)

    @mapping[models.accounts.sole.external_account_id.to_s] = models.blobs.all.index_by(&:id)
    @attachments[models.accounts.sole.external_account_id.to_s] = models.attachments.all.index_by(&:id)
    @users[models.accounts.sole.external_account_id.to_s] = models.users.all.index_by(&:id)
  end

  def ingest_untenanted(untenanted_db_path)
    untenanted = Models.new(untenanted_db_path)

    @memberships = untenanted.memberships.all.index_by(&:id)
    @identities = untenanted.identities.all.index_by(&:id)
  end

  def perform
    fix_avatars
    fix_mentions
    fix_attachments

    pp [ @processed, @skipped ]
  end

  private
    def fix_avatars
      User.all.active.preload(:identity).find_each do |user|
        tenant = user.account.external_account_id.to_s
        email_address = user.identity.email_address

        membership = @memberships.values.find { |m| m.tenant == tenant && @identities[m.identity_id]&.email_address == email_address }
        old_user = @users[tenant]&.values&.find { |u| u.membership_id == membership&.id }

        next if user.avatar.attached? || old_user.nil?

        old_avatar_attachment = @attachments[tenant]&.values&.find do |attachment|
          attachment.record_type == "User" && attachment.record_id == old_user.id && attachment.name == "avatar"
        end

        if old_avatar_attachment.nil?
          @skipped += 1
          next
        end


        old_blob = old_avatar_attachment.blob

        if old_blob.nil?
          @skipped += 1
          next
        end

        new_blob = ActiveStorage::Blob.find_by(key: old_blob.key)

        unless new_blob
          new_blob = ActiveStorage::Blob.create!(
            account_id: user.account_id,
            byte_size: old_blob.byte_size,
            checksum: old_blob.checksum,
            content_type: old_blob.content_type,
            created_at: old_blob.created_at,
            filename: old_blob.filename,
            key: old_blob.key,
            metadata: old_blob.metadata,
            service_name: old_blob.service_name
          )
        end

          ActiveStorage::Attachment.find_or_create_by!(
            account_id: user.account_id,
            blob_id: new_blob.id,
            name: "avatar",
            record: user
          )

        @processed += 1
      end
    end

    def fix_mentions
      ActionText::RichText.where("body LIKE '%action-text-attachment%'").find_each do |rich_text|
        rich_text.body.send(:attachment_nodes).each do |node|
          next unless node["content-type"] == "application/vnd.actiontext.mention"

          sgid = SignedGlobalID.parse(node["sgid"], for: ActionText::Attachable::LOCATOR_NAME)

          user = @users.dig(sgid.params[:tenant], sgid.model_id.to_i)
          membership = @memberships[user&.membership_id]
          unless membership
            @skipped += 1
            next
          end
          identity = @identities[membership&.identity_id]
          unless identity
            @skipped += 1
            next
          end

          new_identity = Identity.find_by(email_address: identity.email_address)
          new_account = Account.find_by(external_account_id: sgid.params[:tenant])
          new_user = User.find_by(identity: new_identity, account: new_account)
          new_sgid = new_user.attachable_sgid

          node["sgid"] = new_sgid.to_s
        end
        rich_text.save!
      end
    end

    def fix_attachments
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
      rescue ActiveStorage::FileNotFoundError
        @skipped += 1
        next
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
    models = self
    @attachments ||= Class.new(application_record) do
      self.table_name = "active_storage_attachments"

      def blob
        models.blobs.find_by(id: blob_id)
      end
    end
  end

  def users
    @users ||= Class.new(application_record) do
      self.table_name = "users"
    end
  end

  def identities
    @identities ||= Class.new(application_record) do
      self.table_name = "identities"
    end
  end

  def memberships
    @memberships ||= Class.new(application_record) do
      self.table_name = "memberships"
    end
  end
end

# tenanted_db_paths = ARGV
tenanted_db_paths = Dir[Rails.root.join("storage/tenants/production/*/db/main.sqlite3")]
untenanted_db_path = Rails.root.join("storage/untenanted/production.sqlite3")

if tenanted_db_paths.empty?
  $stderr.puts "Error: at least one tenanted database path is required"
  $stderr.puts
  exit 1
end

fix = FixActiveStorage.new

fix.ingest_untenanted(untenanted_db_path)

tenanted_db_paths.each_with_index do |db_path, _index|
  fix.ingest_blob_keys(db_path)
end

fix.perform
