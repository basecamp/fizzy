module Boards::WorkPlansHelper
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
