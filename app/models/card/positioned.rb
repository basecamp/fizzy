module Card::Positioned
  extend ActiveSupport::Concern

  included do
    scope :ordered_by_position, ->(fallback_order = nil) do
      relation = order(Arel.sql("cards.position IS NULL"), position: :asc)
      fallback_order.present? ? relation.order(fallback_order) : relation
    end
  end
end

