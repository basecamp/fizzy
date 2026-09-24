module Boards::WorkPlansHelper
  def button_to_work_plan(board)
    tag.button type: "button", class: "btn btn--circle-mobile",
      data: { controller: "tooltip", action: "click->dialog#open", dialog_target: "focusMouse",
        bridge__overflow_menu_target: "item", bridge_title: "Assign work" } do
      icon_tag("everyone") + tag.span("Assign work", class: "for-screen-reader")
    end
  end

  def urgency_badges(work_unit)
    badges = []

    if work_unit.due_on
      due_on = Date.iso8601(work_unit.due_on)
      distance = due_on - Time.zone.today

      if distance < 0
        badges << "Overdue"
      elsif distance.zero?
        badges << "Due today"
      elsif distance <= 7
        badges << "Due in #{distance.to_i}d"
      end
    end

    badges << "Golden" if work_unit.golden
    badges << "Stalled" if work_unit.stalled

    badges.join(" • ")
  end
end
