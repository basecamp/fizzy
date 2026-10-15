class TimeSlot
  attr_reader :slot

  HUMAN_NAMES_BY_VALUE = {
    "latertoday" => "Later Today",
    "tomorrow" => "Tomorrow",
    "thisweekend" => "This Weekend",
    "nextweek" => "Next Week",
    "surprise" => "Surprise Me"
  }

  class << self
    def for(slot)
      new.for(slot)
    end

    def initialize(slot)
      @slot = slot
    end
  end

  def for(slot)
    case slot
    when "latertoday"
      Time.current.change(hour: 18)
    when "tomorrow"
      1.day.from_now.change(hour: 8)
    when "thisweekend"
      Date.current.next_occurring(:saturday).in_time_zone.change(hour: 8)
    when "nextweek"
      Date.current.next_occurring(:monday).in_time_zone.change(hour: 8)
    when "surprise"
      rand(2..14).days.from_now.change(hour: 8)
    end
  end
end
