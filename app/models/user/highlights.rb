module User::Highlights
  extend ActiveSupport::Concern

  included do
    has_many :weekly_highlights, class_name: "User::WeeklyHighlights", dependent: :destroy
  end

  class_methods do
    def generate_all_weekly_highlights_later
      User::Highlights::GenerateAllJob.perform_later
    end

    def generate_all_weekly_highlights
      # We're not interested in parallelizing individual generation. Better for AI quota limits and, also,
      # most summaries will be reused for users accessing the same collections.
      active.find_each(&:generate_weekly_highlights)
    end
  end

  def generate_weekly_highlights(date = Time.current)
    in_time_zone do
      weekly_highlights_for(date) || create_weekly_highlights_for(date)
    end
  end

  def weekly_highlights_for(date)
    in_time_zone do
      weekly_highlights.find_by(starts_at: highlights_starts_at(date).to_date)&.period_highlights
    end
  end

  private
    def create_weekly_highlights_for(date)
      # Outside of transaction as generating highlights can be a slow operation
      PeriodHighlights.create_or_find_for(collections, starts_at: highlights_starts_at(date), duration: 1.week).tap do |period_highlights|
        if period_highlights
          weekly_highlights.create! period_highlights: period_highlights, starts_at: highlights_starts_at(date).to_date
        end
      end
    end

    def highlights_starts_at(date = Time.current)
      date = date.in_time_zone(timezone)
      date.beginning_of_week(:sunday) - 1.week
    end
end
