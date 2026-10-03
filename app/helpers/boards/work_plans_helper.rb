module Boards::WorkPlansHelper
  def link_to_work_plan(board)
    link_to board_work_plan_path(board_id: board),
        class: "btn btn--circle-mobile",
        data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: "Assign work" } do
      icon_tag("everyone") + tag.span("Assign work", class: "for-screen-reader")
    end
  end

  def urgency_badges(card)
    badges = []

    if card.due_on
      distance = card.due_on - Time.zone.today

      if distance.negative?
        badges << "Overdue"
      elsif distance.zero?
        badges << "Due today"
      elsif distance <= 7
        badges << "Due in #{distance.to_i}d"
      end
    end

    badges << "Golden" if card.golden?
    badges << "Stalled" if card.stalled?

    badges.join(" • ")
  end
end
