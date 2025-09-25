module Card::Entropic
  extend ActiveSupport::Concern

  included do
    scope :entropic_by, ->(period_name) do
      left_outer_joins(collection: :entropy_configuration)
        .where("last_active_at <= DATETIME('now', '-' || COALESCE(entropy_configurations.#{period_name}, ?) || ' seconds')",
          Entropy::Configuration.default.public_send(period_name))
    end

    scope :stagnated, -> { doing.or(on_deck).entropic_by(:auto_reconsider_period) }

    scope :due_to_be_closed, -> { considering.entropic_by(:auto_close_period) }

    scope :closing_soon, -> do
      considering
        .left_outer_joins(collection: :entropy_configuration)
        .where("last_active_at >  DATETIME('now', '-' || COALESCE(entropy_configurations.auto_close_period, ?) || ' seconds')", Entropy::Configuration.default.auto_close_period)
        .where("last_active_at <= DATETIME('now', '-' || CAST(COALESCE(entropy_configurations.auto_close_period, ?) * 0.75 AS INTEGER) || ' seconds')", Entropy::Configuration.default.auto_close_period)
    end

    scope :falling_back_soon, -> do
      doing.or(on_deck)
        .left_outer_joins(collection: :entropy_configuration)
        .where("last_active_at >  DATETIME('now', '-' || COALESCE(entropy_configurations.auto_reconsider_period, ?) || ' seconds')", Entropy::Configuration.default.auto_reconsider_period)
        .where("last_active_at <= DATETIME('now', '-' || CAST(COALESCE(entropy_configurations.auto_reconsider_period, ?) * 0.75 AS INTEGER) || ' seconds')", Entropy::Configuration.default.auto_reconsider_period)
    end

    delegate :auto_close_period, :auto_reconsider_period, to: :collection
  end

  class_methods do
    def auto_close_all_due
      due_to_be_closed.find_each do |card|
        card.close(user: User.system, reason: "Closed", event: :auto_closed)
      end
    end

    def auto_reconsider_all_stagnated
      stagnated.find_each(&:reconsider)
    end
  end

  def entropy
    Card::Entropy.for(self)
  end

  def entropic?
    entropy.present?
  end

  def stagnated?
    card.doing? || card.on_deck?
  end
end
