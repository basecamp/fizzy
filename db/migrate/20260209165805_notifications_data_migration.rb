class NotificationsDataMigration < ActiveRecord::Migration[8.2]
  BATCH_SIZE = 10_000

  class Notification < ActiveRecord::Base
    self.table_name = "notifications"
  end

  def change
    reversible do |dir|
      dir.up do
        populate_card_id
        collapse_duplicates
      end
    end

    change_column_null :notifications, :card_id, false
    add_index :notifications, [ :user_id, :card_id ], unique: true
  end

  private
    def populate_card_id
      execute(<<~SQL)
        UPDATE notifications
        SET card_id = (
          SELECT CASE events.eventable_type
            WHEN 'Card' THEN events.eventable_id
            WHEN 'Comment' THEN (SELECT comments.card_id FROM comments WHERE comments.id = events.eventable_id)
          END
          FROM events
          WHERE events.id = notifications.source_id
        )
        WHERE notifications.card_id IS NULL
          AND notifications.source_type = 'Event'
      SQL

      execute(<<~SQL)
        UPDATE notifications
        SET card_id = (
          SELECT CASE mentions.source_type
            WHEN 'Card' THEN mentions.source_id
            WHEN 'Comment' THEN (SELECT comments.card_id FROM comments WHERE comments.id = mentions.source_id)
          END
          FROM mentions
          WHERE mentions.id = notifications.source_id
        )
        WHERE notifications.card_id IS NULL
          AND notifications.source_type = 'Mention'
      SQL
    end

    def collapse_duplicates
      loop do
        duplicates = Notification.find_by_sql(<<~SQL)
          SELECT user_id, card_id,
                 MAX(id) AS keep_id,
                 COUNT(*) AS total,
                 SUM(CASE WHEN read_at IS NULL THEN 1 ELSE 0 END) AS unread_total
          FROM notifications
          WHERE card_id IS NOT NULL
          GROUP BY user_id, card_id
          HAVING COUNT(*) > 1
          LIMIT #{BATCH_SIZE}
        SQL

        break if duplicates.empty?

        duplicates.each do |row|
          Notification.where(user_id: row.user_id, card_id: row.card_id)
            .where.not(id: row.keep_id)
            .delete_all

          Notification.where(id: row.keep_id)
            .update_all(unread_count: row.unread_total.to_i)
        end
      end

      # Set unread_count for remaining non-collapsed notifications
      execute(<<~SQL)
        UPDATE notifications
        SET unread_count = CASE WHEN read_at IS NULL THEN 1 ELSE 0 END
        WHERE unread_count = 0 AND card_id IS NOT NULL
      SQL
    end
end
