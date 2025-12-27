#!/usr/bin/env ruby

require_relative "../config/environment"
require "pathname"
require "optparse"

class AccountExistsError < StandardError; end

class Import
  FIX_LINK_HOSTS = {
    "fizzy.37signals.com" => "app.fizzy.do",
    "box-car.com" => "app.fizzy.do",
    "app.box-car.com" => "app.fizzy.do"
  }.freeze

  attr_reader :db_path, :untenanted_db_path, :skip_already_imported
  attr_reader :account, :tenant, :mapping

  def initialize(db_path, untenanted_db_path, skip_already_imported: false)
    @db_path = Pathname(db_path)
    @untenanted_db_path = Pathname(untenanted_db_path)
    @skip_already_imported = skip_already_imported
    @mapping = nil
  end

  def import_database
    raise "The given database file doesn't exist" unless db_path.exist?

    @mapping = {}

    duration = ActiveSupport::Benchmark.realtime do
      ApplicationRecord.transaction do
        setup_account

        ActiveRecord::Base.no_touching do
          Current.with(account: account) do
            begin
              Webhook.skip_callback(:create, :after, :create_delinquency_tracker!)
              Comment.skip_callback(:commit, :after, :watch_card_by_creator)
              Comment.skip_callback(:commit, :after, :track_creation)
              Mention.skip_callback(:commit, :after, :watch_source_by_mentionee)
              Notification.skip_callback(:commit, :after, :broadcast_unread)
              Notification.skip_callback(:create, :after, :bundle)
              Reaction.skip_callback(:create, :after, :register_card_activity)
              Card.skip_callback(:save, :before, :set_default_title)
              Card.skip_callback(:update, :after, :handle_board_change)
              ActiveStorage::Blob.skip_callback(:update, :after, :touch_attachments)
              ActiveStorage::Blob.skip_callback(:commit, :after, :update_service_metadata)
              ActiveStorage::Attachment.skip_callback(:commit, :after, :mirror_blob_later)
              ActiveStorage::Attachment.skip_callback(:commit, :after, :analyze_blob_later)
              ActiveStorage::Attachment.skip_callback(:commit, :after, :transform_variants_later)
              ActiveStorage::Attachment.skip_callback(:commit, :after, :purge_dependent_blob_later)
            rescue => e
              puts "⚠️  Warning: Could not skip some callbacks: #{e.message}"
            end

            Event.suppress do
              copy_users
              copy_boards
              copy_accesses
              copy_columns
              copy_cards
              copy_steps
              copy_comments
              copy_mentions
              copy_reactions
              copy_tags
              copy_watches
              copy_pins
            end

            copy_events

            Event.suppress do
              copy_webhooks
              copy_push_subscriptions
              copy_filters
              copy_entropies
            end

            copy_notifications
            copy_notification_bundles

            fix_links

            unless Rails.env.production?
              # Don't spam real webhooks
              Webhook.all.update_all(active: false)
              # Don't send emails to real users
              User::Settings.all.update_all(bundle_email_frequency: :never)
            end
          end
        end
      end
    end

    puts "🎉 Import complete! (#{duration.round(2)}s)"
  rescue AccountExistsError => e
    raise e unless skip_already_imported
  end

  private
    def step(start_message, completion_message)
      puts "⏩ #{start_message}"

      result = nil
      duration = ActiveSupport::Benchmark.realtime do
        result = yield
      end

      interpolations = { duration: "#{duration.round(2)}s" }
      interpolations.merge!(result) if result.is_a?(Hash)
      completion_text = completion_message % interpolations
      puts "✅ #{completion_text}"

      result
    end

    def generate_uuid
      ActiveRecord::Type::Uuid.generate
    end

    def setup_account
      step("Setting up account", "Account set up in %{duration}") do
        oldest_admin = import.users.order(id: :asc).admin.first
        raise "No admin user found in the database" unless oldest_admin

        membership = untenanted.memberships.find(oldest_admin.membership_id)
        account = import.accounts.sole

        new_identity = Identity.find_or_create_by!(email_address: membership.identity.email_address)

        if Account.all.exists?(external_account_id: account.external_account_id)
          raise AccountExistsError, "Account already exists"
        else
          @account = Account.create_with_owner(
            account: {
              external_account_id: account.external_account_id,
              name: account.name.truncate(255, omission: "")
            },
            owner: {
              name: oldest_admin.name.truncate(255, omission: ""),
              identity: new_identity
            }
          )
          @tenant = @account.external_account_id
          @admin = @account.users.find_by(role: :owner)
        end

        old_join_code = import.account_join_codes.sole

        attributes = {
          usage_count: old_join_code.usage_count,
          usage_limit: old_join_code.usage_limit
        }
        attributes[:code] = old_join_code.code unless Account::JoinCode.all.exists?(code: old_join_code.code)

        @account.join_code.update_columns(**attributes)
      end
    end

    def copy_users
      step("Copying users", "Copied %{count} users in %{duration}") do
        mapping[:users] ||= {}
        import.users.find_each do |old_user|
          new_identity = nil

          if old_user.membership_id && old_user.active?
            membership = untenanted.memberships.find(old_user.membership_id)
            new_identity = Identity.find_or_create_by!(email_address: membership.identity.email_address)
          end

          new_user = if new_identity == @admin.identity
            @admin
          else
            User.create!(
              account: account,
              identity: new_identity,
              name: old_user.name.truncate(255, omission: ""),
              role: old_user.role,
              active: old_user.active,
            )
          end

          old_settings = old_user.settings
          if old_settings
            User::Settings.create!(
              user: new_user,
              bundle_email_frequency: old_settings.bundle_email_frequency,
              timezone_name: old_settings.timezone_name
            )
          end

          mapping[:users][old_user.id] = new_user.id
        end

        { count: mapping[:users].size }
      end
    end

    def copy_boards
      step("Copying boards", "Copied %{count} boards in %{duration}") do
        mapping[:boards] ||= {}
        import.boards.find_each do |old_board|
          new_board = Board.create!(
            account_id: account.id,
            creator_id: mapping[:users][old_board.creator_id],
            name: old_board.name.truncate(255, omission: ""),
            all_access: old_board.all_access,
            created_at: old_board.created_at,
            updated_at: old_board.updated_at
          )

          old_publication = old_board.publication
          if old_publication
            Board::Publication.create!(
              board_id: new_board.id,
              key: old_publication.key,
              created_at: old_publication.created_at,
              updated_at: old_publication.updated_at
            )
          end

          mapping[:boards][old_board.id] = new_board.id
        end

        { count: mapping[:boards].size }
      end
    end

    def copy_columns
      step("Copying columns", "Copied %{count} columns in %{duration}") do
        mapping[:columns] ||= {}

        import.columns.find_each do |old_column|
          new_column = Column.create!(
            account_id: account.id,
            board_id: mapping[:boards][old_column.board_id],
            name: old_column.name.truncate(255, omission: ""),
            color: old_column.color,
            position: old_column.position,
            created_at: old_column.created_at,
            updated_at: old_column.updated_at
          )

          mapping[:columns][old_column.id] = new_column.id
        end

        { count: mapping[:columns].size }
      end
    end

    def copy_cards
      step("Copying cards", "Copied %{count} cards in %{duration}") do
        mapping[:cards] ||= {}
        account.update_columns(cards_count: import.cards.maximum(:id) || 0)

        activity_spikes_to_insert = []
        engagements_to_insert = []
        goldnesses_to_insert = []
        not_nows_to_insert = []
        assignments_to_insert = []
        closures_to_insert = []

        import.cards.in_batches(of: 1000) do |batch|
          cards_to_insert = []

          batch.each do |old_card|
            new_id = generate_uuid
            mapping[:cards][old_card.id] = new_id

            # Map old 'creating' status to 'drafted' since it's no longer a valid enum value
            status = old_card.status == "creating" ? "drafted" : old_card.status

            cards_to_insert << {
              id: new_id,
              number: old_card.id,
              account_id: account.id,
              board_id: mapping[:boards][old_card.board_id],
              column_id: old_card.column_id ? mapping[:columns][old_card.column_id] : nil,
              creator_id: mapping[:users][old_card.creator_id],
              title: old_card.title,
              status: status,
              due_on: old_card.due_on,
              last_active_at: old_card.last_active_at,
              created_at: old_card.created_at,
              updated_at: old_card.updated_at
            }

            old_activity_spike = old_card.activity_spike
            if old_activity_spike
              activity_spikes_to_insert << {
                id: generate_uuid,
                account_id: account.id,
                card_id: new_id,
                created_at: old_activity_spike.created_at,
                updated_at: old_activity_spike.updated_at
              }
            end

            old_engagement = old_card.engagement
            if old_engagement
              engagements_to_insert << {
                id: generate_uuid,
                account_id: account.id,
                card_id: new_id,
                status: old_engagement.status,
                created_at: old_engagement.created_at,
                updated_at: old_engagement.updated_at
              }
            end

            old_goldness = old_card.goldness
            if old_goldness
              goldnesses_to_insert << {
                id: generate_uuid,
                account_id: account.id,
                card_id: new_id,
                created_at: old_goldness.created_at,
                updated_at: old_goldness.updated_at
              }
            end

            old_not_now = old_card.not_now
            if old_not_now
              not_nows_to_insert << {
                id: generate_uuid,
                account_id: account.id,
                card_id: new_id,
                user_id: old_not_now.user_id ? mapping[:users][old_not_now.user_id] : nil,
                created_at: old_not_now.created_at,
                updated_at: old_not_now.updated_at
              }
            end

            old_card.assignments.each do |old_assignment|
              assignments_to_insert << {
                id: generate_uuid,
                account_id: account.id,
                card_id: new_id,
                assignee_id: mapping[:users][old_assignment.assignee_id],
                assigner_id: mapping[:users][old_assignment.assigner_id],
                created_at: old_assignment.created_at,
                updated_at: old_assignment.updated_at
              }
            end

            old_closure = old_card.closure
            if old_closure
              closures_to_insert << {
                id: generate_uuid,
                account_id: account.id,
                card_id: new_id,
                user_id: old_closure.user_id ? mapping[:users][old_closure.user_id] : nil,
                created_at: old_closure.created_at,
                updated_at: old_closure.updated_at
              }
            end
          end

          Card.insert_all(cards_to_insert)
        end

        Card::ActivitySpike.insert_all(activity_spikes_to_insert) if activity_spikes_to_insert.any?
        Card::Engagement.insert_all(engagements_to_insert) if engagements_to_insert.any?
        Card::Goldness.insert_all(goldnesses_to_insert) if goldnesses_to_insert.any?
        Card::NotNow.insert_all(not_nows_to_insert) if not_nows_to_insert.any?
        Assignment.insert_all(assignments_to_insert) if assignments_to_insert.any?
        Closure.insert_all(closures_to_insert) if closures_to_insert.any?

        import.cards.find_each do |old_card|
          new_card_id = mapping[:cards][old_card.id]
          new_card = Card.find(new_card_id)
          copy_rich_text(old_card, new_card, "Card", "description")
          copy_attachment(old_card, new_card, "Card", "image")
        end

        { count: mapping[:cards].size }
      end
    end

    def copy_steps
      step("Copying steps", "Copied steps in %{duration}") do
        import.steps.in_batches(of: 1000) do |batch|
          steps_to_insert = []

          batch.each do |old_step|
            steps_to_insert << {
              id: generate_uuid,
              account_id: account.id,
              card_id: mapping[:cards][old_step.card_id],
              content: old_step.content,
              completed: old_step.completed,
              created_at: old_step.created_at,
              updated_at: old_step.updated_at
            }
          end

          Step.insert_all(steps_to_insert)
        end
      end
    end

    def copy_comments
      step("Copying comments", "Copied %{count} comments in %{duration}") do
        mapping[:comments] ||= {}

        import.comments.in_batches(of: 1000) do |batch|
          comments_to_insert = []

          batch.each do |old_comment|
            new_id = generate_uuid
            mapping[:comments][old_comment.id] = new_id

            comments_to_insert << {
              id: new_id,
              account_id: account.id,
              card_id: mapping[:cards][old_comment.card_id],
              creator_id: mapping[:users][old_comment.creator_id],
              created_at: old_comment.created_at,
              updated_at: old_comment.updated_at
            }
          end

          Comment.insert_all(comments_to_insert)
        end

        import.comments.find_each do |old_comment|
          new_comment_id = mapping[:comments][old_comment.id]
          new_comment = Comment.find(new_comment_id)
          copy_rich_text(old_comment, new_comment, "Comment", "body")
        end

        { count: mapping[:comments].size }
      end
    end

    def copy_mentions
      step("Copying mentions", "Copied %{count} mentions in %{duration}") do
        mapping[:mentions] ||= {}

        import.mentions.find_each do |old_mention|
          new_mention = Mention.create!(
            source_type: old_mention.source_type,
            source_id: mapping[old_mention.source_type.tableize.to_sym][old_mention.source_id],
            mentioner_id: mapping[:users][old_mention.mentioner_id],
            mentionee_id: mapping[:users][old_mention.mentionee_id],
            created_at: old_mention.created_at,
            updated_at: old_mention.updated_at
          )

          mapping[:mentions][old_mention.id] = new_mention.id
        end

        { count: mapping[:mentions].size }
      end
    end

    def copy_accesses
      step("Copying accesses", "Copied %{count} accesses in %{duration}") do
        mapping[:accesses] ||= {}

        import.accesses.in_batches(of: 1000) do |batch|
          accesses_to_insert = []

          batch.each do |old_access|
            new_id = generate_uuid
            mapping[:accesses][old_access.id] = new_id

            accesses_to_insert << {
              id: new_id,
              account_id: account.id,
              board_id: mapping[:boards][old_access.board_id],
              user_id: mapping[:users][old_access.user_id],
              involvement: old_access.involvement,
              accessed_at: old_access.accessed_at,
              created_at: old_access.created_at,
              updated_at: old_access.updated_at
            }
          end

          Access.insert_all(accesses_to_insert)
        end

        { count: mapping[:accesses].size }
      end
    end

    def copy_notifications
      step("Copying notifications", "Copied %{count} notifications in %{duration}") do
        mapping[:notifications] ||= {}

        import.notifications.in_batches(of: 1000) do |batch|
          notifications_to_insert = []

          batch.each do |old_notification|
            new_id = generate_uuid
            mapping[:notifications][old_notification.id] = new_id

            notifications_to_insert << {
              id: new_id,
              account_id: account.id,
              user_id: mapping[:users][old_notification.user_id],
              creator_id: old_notification.creator_id ? mapping[:users][old_notification.creator_id] : nil,
              source_type: old_notification.source_type,
              source_id: mapping.fetch(old_notification.source_type.tableize.to_sym)[old_notification.source_id],
              read_at: old_notification.read_at,
              created_at: old_notification.created_at,
              updated_at: old_notification.updated_at
            }
          end

          Notification.insert_all(notifications_to_insert)
        end

        { count: mapping[:notifications].size }
      end
    end

    def copy_notification_bundles
      step("Copying notification bundles", "Copied %{count} notification bundles in %{duration}") do
        mapping[:notification_bundles] ||= {}

        import.notification_bundles.in_batches(of: 1000) do |batch|
          bundles_to_insert = []

          batch.each do |old_bundle|
            new_id = generate_uuid
            mapping[:notification_bundles][old_bundle.id] = new_id

            bundles_to_insert << {
              id: new_id,
              account_id: account.id,
              user_id: mapping[:users][old_bundle.user_id],
              status: old_bundle.status,
              starts_at: old_bundle.starts_at,
              ends_at: old_bundle.ends_at,
              created_at: old_bundle.created_at,
              updated_at: old_bundle.updated_at
            }
          end

          Notification::Bundle.insert_all(bundles_to_insert)
        end

        { count: mapping[:notification_bundles].size }
      end
    end

    def copy_entropies
      step("Copying entropies", "Copied entropies in %{duration}") do
        import.entropies.find_each do |old_entropy|
          container_id = case old_entropy.container_type
          when "Account" then account.id
          when "Board" then mapping[:boards][old_entropy.container_id]
          when "Card" then mapping[:cards][old_entropy.container_id]
          else next
          end

          Entropy.find_or_create_by!(account_id: account.id, container_type: old_entropy.container_type, container_id: container_id) do |entropy|
            entropy.auto_postpone_period = old_entropy.auto_postpone_period || 0
            entropy.created_at = old_entropy.created_at
            entropy.updated_at = old_entropy.updated_at
          end
        end
      end
    end

    def copy_filters
      step("Copying filters", "Copied %{count} filters in %{duration}") do
        mapping[:filters] ||= {}

        # First, insert all filters
        import.filters.in_batches(of: 1000) do |batch|
          filters_to_insert = []

          batch.each do |old_filter|
            new_id = generate_uuid
            mapping[:filters][old_filter.id] = new_id

            filters_to_insert << {
              id: new_id,
              account_id: account.id,
              creator_id: mapping[:users][old_filter.creator_id],
              params_digest: old_filter.params_digest,
              fields: old_filter.fields,
              created_at: old_filter.created_at,
              updated_at: old_filter.updated_at
            }
          end

          Filter.insert_all(filters_to_insert)
        end

        # Then, copy HABTM associations for each filter
        import.filters.find_each do |old_filter|
          new_filter = Filter.find(mapping[:filters][old_filter.id])

          # Copy HABTM associations by finding valid mapped IDs first
          assignee_ids = import.assignees_filters.where(filter_id: old_filter.id)
            .filter_map { |join| mapping[:users][join.assignee_id] }
          new_filter.assignee_ids = assignee_ids if assignee_ids.any?

          creator_ids = import.creators_filters.where(filter_id: old_filter.id)
            .filter_map { |join| mapping[:users][join.creator_id] }
          new_filter.creator_ids = creator_ids if creator_ids.any?

          closer_ids = import.closers_filters.where(filter_id: old_filter.id)
            .filter_map { |join| mapping[:users][join.closer_id] }
          new_filter.closer_ids = closer_ids if closer_ids.any?

          board_ids = import.boards_filters.where(filter_id: old_filter.id)
            .filter_map { |join| mapping[:boards][join.board_id] }
          new_filter.board_ids = board_ids if board_ids.any?

          tag_ids = import.filters_tags.where(filter_id: old_filter.id)
            .filter_map { |join| mapping[:tags][join.tag_id] }
          new_filter.tag_ids = tag_ids if tag_ids.any?
        end

        { count: mapping[:filters].size }
      end
    end

    def copy_events
      step("Copying events", "Copied %{count} events in %{duration}") do
        mapping[:events] ||= {}

        import.events.in_batches(of: 1000) do |batch|
          events_to_insert = []

          batch.each do |old_event|
            new_id = generate_uuid
            mapping[:events][old_event.id] = new_id

            events_to_insert << {
              id: new_id,
              account_id: account.id,
              board_id: mapping[:boards][old_event.board_id],
              creator_id: mapping[:users][old_event.creator_id],
              eventable_type: old_event.eventable_type,
              eventable_id: mapping[old_event.eventable_type.tableize.to_sym][old_event.eventable_id],
              action: old_event.action,
              particulars: old_event.particulars,
              created_at: old_event.created_at,
              updated_at: old_event.updated_at
            }
          end

          Event.insert_all(events_to_insert)
        end

        { count: mapping[:events].size }
      end
    end

    def copy_rich_text(old_record, new_record, record_type, name)
      old_rich_text = import.rich_texts.find_by(record_type: record_type, record_id: old_record.id, name: name)
      return unless old_rich_text

      new_rich_text = ActionText::RichText.create!(
        record: new_record,
        name: name,
        body: old_rich_text.body,
        created_at: old_rich_text.created_at,
        updated_at: old_rich_text.updated_at
      )

      mapping[:rich_text] ||= {}
      mapping[:rich_text][old_rich_text.id] = new_rich_text.id

      import.attachments.where(record_type: "ActionText::RichText", record_id: old_rich_text.id).each do |old_attachment|
        copy_attachment(old_rich_text, new_rich_text, "ActionText::RichText", old_attachment.name)
      end
    end

    def copy_attachment(old_record, new_record, record_type, name)
      old_attachment = import.attachments.find_by(record_type: record_type, record_id: old_record.id, name: name)
      return unless old_attachment

      old_blob = import.blobs.find(old_attachment.blob_id)

      new_blob = ActiveStorage::Blob.find_or_create_by!(key: old_blob.key) do |blob|
        blob.filename = old_blob.filename
        blob.content_type = old_blob.content_type
        blob.metadata = old_blob.metadata
        blob.service_name = old_blob.service_name
        blob.byte_size = old_blob.byte_size
        blob.checksum = old_blob.checksum
        blob.created_at = old_blob.created_at
      end

      mapping[:blobs] ||= {}
      mapping[:blobs][old_blob.id] = new_blob.id

      # Copy variant records to prevent ActiveStorage from regenerating them
      copy_variant_records(old_blob, new_blob)

      new_attachment = ActiveStorage::Attachment.find_or_create_by!(
        name: name,
        record: new_record,
        blob: new_blob,
        created_at: old_attachment.created_at
      )

      mapping[:attachments] ||= {}
      mapping[:attachments][old_attachment.id] = new_attachment.id
    end

    def copy_variant_records(old_blob, new_blob)
      import.variant_records.where(blob_id: old_blob.id).each do |old_variant_record|
        old_variant_blob = import.blobs.find_by(id: old_variant_record.id)
        next unless old_variant_blob

        new_variant_blob = ActiveStorage::Blob.find_or_create_by!(key: old_variant_blob.key) do |blob|
          blob.filename = old_variant_blob.filename
          blob.content_type = old_variant_blob.content_type
          blob.metadata = old_variant_blob.metadata
          blob.service_name = old_variant_blob.service_name
          blob.byte_size = old_variant_blob.byte_size
          blob.checksum = old_variant_blob.checksum
          blob.created_at = old_variant_blob.created_at
        end

        mapping[:blobs] ||= {}
        mapping[:blobs][old_variant_blob.id] = new_variant_blob.id

        ActiveStorage::VariantRecord.find_or_create_by!(
          id: new_variant_blob.id,
          account_id: account.id,
          blob_id: new_blob.id,
          variation_digest: old_variant_record.variation_digest
        )
      end
    end

    def copy_reactions
      step("Copying reactions", "Copied %{count} reactions in %{duration}") do
        mapping[:reactions] ||= {}
        import.reactions.find_each do |old_reaction|
          # Truncate content to 16 characters to match current column limit
          content = old_reaction.content.truncate(16, omission: "")

          new_reaction = Reaction.create!(
            comment_id: mapping[:comments][old_reaction.comment_id],
            reacter_id: mapping[:users][old_reaction.reacter_id],
            content: content,
            created_at: old_reaction.created_at,
            updated_at: old_reaction.updated_at
          )

          mapping[:reactions][old_reaction.id] = new_reaction.id
        end

        { count: mapping[:reactions].size }
      end
    end

    def copy_tags
      step("Copying tags", "Copied %{tags} tags and %{taggings} taggings in %{duration}") do
        mapping[:tags] ||= {}
        mapping[:taggings] ||= {}

        import.tags.find_each do |old_tag|
          new_tag = account.tags.find_or_create_by!(title: old_tag.title) do |t|
            t.created_at = old_tag.created_at
            t.updated_at = old_tag.updated_at
          end

          mapping[:tags][old_tag.id] = new_tag.id
        end

        import.taggings.find_each do |old_tagging|
          new_tagging = Tagging.create!(
            tag_id: mapping[:tags][old_tagging.tag_id],
            card_id: mapping[:cards][old_tagging.card_id],
            created_at: old_tagging.created_at,
            updated_at: old_tagging.updated_at
          )

          mapping[:taggings][old_tagging.id] = new_tagging.id
        end

        { tags: mapping[:tags].size, taggings: mapping[:taggings].size }
      end
    end

    def copy_watches
      step("Copying watches", "Copied %{count} watches in %{duration}") do
        mapping[:watches] ||= {}

        import.watches.in_batches(of: 1000) do |batch|
          watches_to_insert = []

          batch.each do |old_watch|
            new_id = generate_uuid
            mapping[:watches][old_watch.id] = new_id

            watches_to_insert << {
              id: new_id,
              account_id: account.id,
              user_id: mapping[:users][old_watch.user_id],
              card_id: mapping[:cards][old_watch.card_id],
              watching: old_watch.watching,
              created_at: old_watch.created_at,
              updated_at: old_watch.updated_at
            }
          end

          Watch.insert_all(watches_to_insert)
        end

        { count: mapping[:watches].size }
      end
    end

    def copy_pins
      step("Copying pins", "Copied %{count} pins in %{duration}") do
        mapping[:pins] ||= {}

        import.pins.in_batches(of: 1000) do |batch|
          pins_to_insert = []

          batch.each do |old_pin|
            new_id = generate_uuid
            mapping[:pins][old_pin.id] = new_id

            pins_to_insert << {
              id: new_id,
              account_id: account.id,
              user_id: mapping[:users][old_pin.user_id],
              card_id: mapping[:cards][old_pin.card_id],
              created_at: old_pin.created_at,
              updated_at: old_pin.updated_at
            }
          end

          Pin.insert_all(pins_to_insert)
        end

        { count: mapping[:pins].size }
      end
    end

    def copy_webhooks
      step("Copying webhooks", "Copied %{webhooks} webhooks and %{deliveries} deliveries in %{duration}") do
        mapping[:webhooks] ||= {}
        mapping[:webhook_deliveries] ||= {}

        import.webhooks.find_each do |old_webhook|
          subscribed_actions = old_webhook.subscribed_actions
          subscribed_actions = JSON.parse(subscribed_actions) if subscribed_actions.is_a?(String)

          new_webhook = Webhook.create!(
            account_id: account.id,
            board_id: mapping[:boards][old_webhook.board_id],
            name: old_webhook.name.truncate(255, omission: ""),
            url: old_webhook.url,
            signing_secret: old_webhook.signing_secret,
            subscribed_actions: subscribed_actions,
            active: old_webhook.active,
            created_at: old_webhook.created_at,
            updated_at: old_webhook.updated_at
          )

          mapping[:webhooks][old_webhook.id] = new_webhook.id

          old_tracker = import.webhook_delinquency_trackers.find_by(webhook_id: old_webhook.id)
          if old_tracker
            Webhook::DelinquencyTracker.find_or_create_by!(webhook_id: new_webhook.id) do |tracker|
              tracker.consecutive_failures_count = old_tracker.consecutive_failures_count
              tracker.first_failure_at = old_tracker.first_failure_at
              tracker.created_at = old_tracker.created_at
              tracker.updated_at = old_tracker.updated_at
            end
          end
        end

        import.webhook_deliveries.find_each do |old_delivery|
          new_delivery = Webhook::Delivery.create!(
            webhook_id: mapping[:webhooks][old_delivery.webhook_id],
            event_id: mapping[:events][old_delivery.event_id],
            state: old_delivery.state,
            request: old_delivery.request,
            response: old_delivery.response,
            created_at: old_delivery.created_at,
            updated_at: old_delivery.updated_at
          )

          mapping[:webhook_deliveries][old_delivery.id] = new_delivery.id
        end

        { webhooks: mapping[:webhooks].size, deliveries: mapping[:webhook_deliveries].size }
      end
    end

    def copy_push_subscriptions
      step("Copying push subscriptions", "Copied %{count} push subscriptions in %{duration}") do
        mapping[:push_subscriptions] ||= {}

        import.push_subscriptions.find_each do |old_subscription|
          new_subscription = Push::Subscription.create!(
            account_id: account.id,
            user_id: mapping[:users][old_subscription.user_id],
            endpoint: old_subscription.endpoint,
            p256dh_key: old_subscription.p256dh_key,
            auth_key: old_subscription.auth_key,
            user_agent: old_subscription.user_agent,
            created_at: old_subscription.created_at,
            updated_at: old_subscription.updated_at
          )

          mapping[:push_subscriptions][old_subscription.id] = new_subscription.id
        end

        { count: mapping[:push_subscriptions].size }
      end
    end

    def fix_links
      step("Fixing links", "Fixed %{count} links in %{duration}") do
        mapping[:fixed_links] ||= {}

        ActionText::RichText.where(id: mapping[:rich_text]&.values).find_each do |rich_text|
          fragment = rich_text.body.fragment
          fixed_link = false

          fragment.find_all("a[href]").each do |link|
            url = link["href"]
            uri = URI.parse(url) rescue nil

            if uri
              uri.host = FIX_LINK_HOSTS[uri.host] if uri.absolute? && FIX_LINK_HOSTS.key?(uri.host)
              params = Rails.application.routes.recognize_path(uri.path) rescue {}

              if params[:controller] == "cards" && params[:action] == "show" && params[:id] && mapping[:cards][params[:id].to_i]
                uri.path = Rails.application.routes.url_helpers.card_path(mapping[:cards][params[:id].to_i])
              elsif params[:controller] == "boards" && params[:action] == "show" && params[:id] && mapping[:boards][params[:id].to_i]
                uri.path = Rails.application.routes.url_helpers.board_path(mapping[:boards][params[:id].to_i])
              end

              link["href"] = uri.to_s
              mapping[:fixed_links][url] = link["href"]
              fixed_link = true
            end
          end

          rich_text.update!(body: fragment.to_html) if fixed_link
        end

        { count: mapping[:fixed_links].size }
      end
    end

    def import
      @import ||= Models.new(db_path)
    rescue => e
      $stderr.puts e.backtrace.join("\n") if ENV["DEBUG"]
      raise "Couldn't open the given database: #{e}"
    end

    def untenanted
      @untenanted ||= Models.new(untenanted_db_path)
    rescue => e
      $stderr.puts e.backtrace.join("\n") if ENV["DEBUG"]
      raise "Couldn't open the given untenanted database: #{e}"
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

  def identities
    @identities ||= Class.new(application_record) do
      self.table_name = "identities"
    end
  end

  def memberships
    @memberships ||= begin
      models = self
      Class.new(application_record) do
        self.table_name = "memberships"

        def identity
          @identity ||= models.identities.find_by(id: identity_id)
        end
      end
    end
  end

  def accounts
    @accounts ||= Class.new(application_record) do
      self.table_name = "accounts"
    end
  end

  def account_join_codes
    @account_join_codes ||= Class.new(application_record) do
      self.table_name = "account_join_codes"
    end
  end

  def users
    @users ||= begin
      models = self
      Class.new(application_record) do
        self.table_name = "users"

        def settings
          @settings ||= models.user_settings.find_by(user_id: id)
        end
      end
    end
  end

  def boards
    @boards ||= begin
      models = self
      Class.new(application_record) do
        self.table_name = "boards"

        def publication
          @publication ||= models.board_publications.find_by(board_id: id)
        end
      end
    end
  end

  def columns
    @columns ||= Class.new(application_record) do
      self.table_name = "columns"
    end
  end

  def cards
    @cards ||= begin
      models = self
      Class.new(application_record) do
        self.table_name = "cards"

        def activity_spike
          @activity_spike ||= models.card_activity_spikes.find_by(card_id: id)
        end

        def engagement
          @engagement ||= models.card_engagements.find_by(card_id: id)
        end

        def goldness
          @goldness ||= models.card_goldnesses.find_by(card_id: id)
        end

        def not_now
          @not_now ||= models.card_not_nows.find_by(card_id: id)
        end

        def assignments
          models.assignments.where(card_id: id)
        end

        def closure
          @closure ||= models.closures.find_by(card_id: id)
        end
      end
    end
  end

  def comments
    @comments ||= Class.new(application_record) do
      self.table_name = "comments"
    end
  end

  def steps
    @steps ||= Class.new(application_record) do
      self.table_name = "steps"
    end
  end

  def reactions
    @reactions ||= Class.new(application_record) do
      self.table_name = "reactions"
    end
  end

  def tags
    @tags ||= Class.new(application_record) do
      self.table_name = "tags"
    end
  end

  def taggings
    @taggings ||= Class.new(application_record) do
      self.table_name = "taggings"
    end
  end

  def watches
    @watches ||= Class.new(application_record) do
      self.table_name = "watches"
    end
  end

  def pins
    @pins ||= Class.new(application_record) do
      self.table_name = "pins"
    end
  end

  def webhooks
    @webhooks ||= Class.new(application_record) do
      self.table_name = "webhooks"
    end
  end

  def webhook_deliveries
    @webhook_deliveries ||= Class.new(application_record) do
      self.table_name = "webhook_deliveries"
    end
  end

  def webhook_delinquency_trackers
    @webhook_delinquency_trackers ||= Class.new(application_record) do
      self.table_name = "webhook_delinquency_trackers"
    end
  end

  def push_subscriptions
    @push_subscriptions ||= Class.new(application_record) do
      self.table_name = "push_subscriptions"
    end
  end

  def assignments
    @assignments ||= Class.new(application_record) do
      self.table_name = "assignments"
    end
  end

  def closures
    @closures ||= Class.new(application_record) do
      self.table_name = "closures"
    end
  end

  def accesses
    @accesses ||= Class.new(application_record) do
      self.table_name = "accesses"
    end
  end

  def events
    @events ||= Class.new(application_record) do
      self.table_name = "events"
    end
  end

  def rich_texts
    @rich_texts ||= Class.new(application_record) do
      self.table_name = "action_text_rich_texts"
    end
  end

  def attachments
    @attachments ||= Class.new(application_record) do
      self.table_name = "active_storage_attachments"
    end
  end

  def blobs
    @blobs ||= Class.new(application_record) do
      self.table_name = "active_storage_blobs"
    end
  end

  def variant_records
    @variant_records ||= Class.new(application_record) do
      self.table_name = "active_storage_variant_records"
    end
  end

  def user_settings
    @user_settings ||= Class.new(application_record) do
      self.table_name = "user_settings"
    end
  end

  def board_publications
    @board_publications ||= Class.new(application_record) do
      self.table_name = "board_publications"
    end
  end

  def card_activity_spikes
    @card_activity_spikes ||= Class.new(application_record) do
      self.table_name = "card_activity_spikes"
    end
  end

  def card_engagements
    @card_engagements ||= Class.new(application_record) do
      self.table_name = "card_engagements"
    end
  end

  def card_goldnesses
    @card_goldnesses ||= Class.new(application_record) do
      self.table_name = "card_goldnesses"
    end
  end

  def card_not_nows
    @card_not_nows ||= Class.new(application_record) do
      self.table_name = "card_not_nows"
    end
  end

  def mentions
    @mentions ||= Class.new(application_record) do
      self.table_name = "mentions"
    end
  end

  def notifications
    @notifications ||= Class.new(application_record) do
      self.table_name = "notifications"
    end
  end

  def notification_bundles
    @notification_bundles ||= Class.new(application_record) do
      self.table_name = "notification_bundles"
    end
  end

  def entropies
    @entropies ||= Class.new(application_record) do
      self.table_name = "entropies"
    end
  end

  def filters
    @filters ||= Class.new(application_record) do
      self.table_name = "filters"
    end
  end

  def assignees_filters
    @assignees_filters ||= Class.new(application_record) do
      self.table_name = "assignees_filters"
    end
  end

  def assigners_filters
    @assigners_filters ||= Class.new(application_record) do
      self.table_name = "assigners_filters"
    end
  end

  def boards_filters
    @boards_filters ||= Class.new(application_record) do
      self.table_name = "boards_filters"
    end
  end

  def closers_filters
    @closers_filters ||= Class.new(application_record) do
      self.table_name = "closers_filters"
    end
  end

  def creators_filters
    @creators_filters ||= Class.new(application_record) do
      self.table_name = "creators_filters"
    end
  end

  def filters_tags
    @filters_tags ||= Class.new(application_record) do
      self.table_name = "filters_tags"
    end
  end
end

options = {
  skip_already_imported: false
}

parser = OptionParser.new do |parser|
  parser.banner = "Usage: #{$PROGRAM_NAME} [options] <tenanted_db_path>..."

  parser.on("--untenanted-db-path PATH", "Path to the untenanted database") do |path|
    options[:untenanted_db_path] = path
  end

  parser.on("--skip-already-imported", "Skip import if account already exists") do
    options[:skip_already_imported] = true
  end

  parser.on("-h", "--help", "Show this help message") do
    puts parser
    exit
  end
end

parser.parse!

untenanted_db_path = options[:untenanted_db_path]
tenanted_db_paths = ARGV

if untenanted_db_path.nil?
  $stderr.puts "Error: --untenanted-db-path is required"
  $stderr.puts
  $stderr.puts parser
  exit 1
end

if tenanted_db_paths.empty?
  $stderr.puts "Error: at least one tenanted database path is required"
  $stderr.puts
  $stderr.puts parser
  exit 1
end

total_imported = 0

duration = ActiveSupport::Benchmark.realtime do
  tenanted_db_paths.each_with_index do |db_path, index|
    puts
    puts "="*80
    puts "Processing database #{index + 1}/#{tenanted_db_paths.size}: #{db_path}"
    puts "="*80

    Import.new(db_path, untenanted_db_path, skip_already_imported: options[:skip_already_imported]).import_database
    total_imported += 1
  end
end

puts
puts "="*80
puts "Summary:"
puts "  Imported: #{total_imported}"
puts "  Total time: #{duration.round(2)} seconds"
puts "="*80
