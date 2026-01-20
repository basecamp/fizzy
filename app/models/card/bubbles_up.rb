module Card::BubblesUp
  extend ActiveSupport::Concern

  included do
    has_one :bubble_up, dependent: :destroy, class_name: "Card::BubbleUp"
  end

  def bubble_up?
    bubble_up.present?
  end

  def bubbling?
    bubble_up? && Time.current.before?(bubble_up.resurface_at)
  end

  def bubbled?
    bubble_up? && Time.current.after?(bubble_up.resurface_at)
  end

  def bubble_up_at(time)
    postpone unless postponed?
    bubble_up ||= association(:bubble_up).reader || self.build_bubble_up
    bubble_up.update resurface_at: time
  end

  def pop
    bubble_up&.destroy
  end
end
