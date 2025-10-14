# Contains an AI-generated summary for a given set of events. You create these summaries with a time window
# and a set of collections. We only store a key derived from the accessible events for those collections,
# so that we reuse the same summary for users with different time zones or different accesses as long as the activity
# is the same. This is important to keep AI costs down.
class PeriodHighlights < ApplicationRecord
  has_many :weekly_highlights, class_name: "User::WeeklyHighlights"

  class << self
    def create_or_find_for(collections, starts_at:, duration: 1.week)
      self.for(collections, starts_at:, duration:) || create_for(collections, starts_at:, duration:)
    end

    def for(collections, starts_at:, duration: 1.week)
      period = Period.new(collections, starts_at:, duration:)
      find_by(key: period.key) if period.has_enough_activity?
    end

    private
      def create_for(collections, starts_at:, duration: 1.week)
        period = Period.new(collections, starts_at:, duration:)

        if period.has_enough_activity?
          summarizer = Event::Summarizer.new(period.events)
          summarized_content = summarizer.summarized_content # outside of transaction as this can be slow

          create_or_find_by!(key: period.key) do |record|
            record.content = summarized_content
            record.cost_in_microcents = summarizer.cost.in_microcents
          end
        end
      end
  end

  def ends_at
    starts_at + duration
  end

  def to_html
    renderer = Redcarpet::Render::HTML.new
    markdowner = Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true, superscript: true,)
    markdowner.render(content).html_safe
  end
end
