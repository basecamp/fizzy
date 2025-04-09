module Card::Boostable
  extend ActiveSupport::Concern

  included do
    scope :ordered_by_boosts, -> { order boosts_count: :desc }
  end

  def boost!(count = 1)
    count = count.to_i
    count = 1 if count < 1

    transaction do
      track_event :boosted, count: count
      update! boosts_count: count
      rescore
    end
  end
end
