module BubbleUpHelper
  def bubble_up_options_for(card)
    if card.bubble_up?
      {
        isPostponed: card.postponed?,
        resurfaceAt: card.bubble_up.resurface_at.iso8601
      }
    end
  end

  def slot_too_soon(slot)
    slot == "latertoday" && Time.current.hour > 16 ? true : false
  end
end
