# Repair task — reindexes every searchable Card and Comment in the database.
# Intended to be invoked manually after a search-index loss event. Not a recurring job.
#
# Idempotent: Searchable#reindex upserts by (searchable_type, searchable_id).
# Continuable: if the worker is interrupted, the job resumes from the last-processed id.
#
# `rich_text_limit` is a safety valve against unbounded bodies: records whose rich text
# exceeds the limit (in bytes) are filtered out at the SQL level, so they never materialize
# in Ruby. Without it, a single pathological body can stall the batch query or OOM the
# worker during preload, which has happened in practice.
#
# Usage:
#   SearchReindexJob.perform_later
#   SearchReindexJob.perform_later(batch_size: 500, log_every: 100, rich_text_limit: 50_000)
class SearchReindexJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :backend

  def perform(batch_size: 100, log_every: 1000, rich_text_limit: 100_000)
    step :cards do |step|
      processed = 0
      Card.published
          .left_joins(:rich_text_description)
          .where("action_text_rich_texts.body IS NULL OR OCTET_LENGTH(action_text_rich_texts.body) <= ?", rich_text_limit)
          .includes(:rich_text_description)
          .find_each(start: step.cursor, batch_size: batch_size) do |card|
        safely_reindex(card)
        processed += 1
        log_progress(:cards, processed, card.id) if (processed % log_every).zero?
        step.advance! from: card.id
      end
    end

    step :comments do |step|
      processed = 0
      Comment.joins(:card).merge(Card.published)
             .left_joins(:rich_text_body)
             .where("action_text_rich_texts.body IS NULL OR OCTET_LENGTH(action_text_rich_texts.body) <= ?", rich_text_limit)
             .includes(:rich_text_body, :card)
             .find_each(start: step.cursor, batch_size: batch_size) do |comment|
        safely_reindex(comment)
        processed += 1
        log_progress(:comments, processed, comment.id) if (processed % log_every).zero?
        step.advance! from: comment.id
      end
    end
  end

  private
    def safely_reindex(record)
      record.reindex
    rescue StandardError => e
      Rails.error.report(e, context: { record_type: record.class.name, record_id: record.id })
    end

    def log_progress(step_name, count, cursor)
      Rails.logger.info { "SearchReindexJob: step=#{step_name} processed=#{count} cursor=#{cursor}" }
    end
end
