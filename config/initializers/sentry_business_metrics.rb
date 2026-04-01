# frozen_string_literal: true

# Business metrics emitted directly via Sentry.metrics.
# These capture domain events that can't be derived from tracing alone.

Rails.application.config.after_initialize do
  next unless Sentry.initialized?

  Card.after_create_commit do
    Sentry.metrics.count("fizzy.cards_created", attributes: { board: board.name })
  end

  Card.after_update_commit do
    if saved_change_to_column_id? && column_id_before_last_save.present?
      from = Column.find_by(id: column_id_before_last_save)&.name || "unknown"
      Sentry.metrics.count("fizzy.cards_moved", attributes: {
        board: board.name, from_column: from, to_column: column&.name || "unknown"
      })
    end
  end

  Comment.after_create_commit do
    Sentry.metrics.count("fizzy.comments_created", attributes: { board: board.name })
  end

  Board.after_create_commit do
    Sentry.metrics.count("fizzy.boards_created")
  end

  Notification.after_create_commit do
    Sentry.metrics.count("fizzy.notifications_sent", attributes: { kind: source_type.underscore })
  end
end
