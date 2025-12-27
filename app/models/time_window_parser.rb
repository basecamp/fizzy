# rbs_inline: enabled

class TimeWindowParser
  attr_reader :now #: ActiveSupport::TimeWithZone

  HUMAN_NAMES_BY_VALUE = {
    "today" => "Today",
    "yesterday" => "Yesterday",
    "thisweek" => "This week",
    "thismonth" => "This month",
    "thisyear" => "This year",
    "lastweek" => "Last week",
    "lastmonth" => "Last month",
    "lastyear" => "Last year"
  }

  VALUES = HUMAN_NAMES_BY_VALUE.keys

  class << self
    def parse(string)
      new.parse(string)
    end

    def human_name_for(value)
      HUMAN_NAMES_BY_VALUE[value]
    end
  end

  #: (?now: ActiveSupport::TimeWithZone) -> void
  def initialize(now: Time.current)
    @now = now
  end

  def parse(string)
    case normalize(string)
    when "today"
      now.beginning_of_day..now.end_of_day
    when "yesterday"
      (now - 1.day).beginning_of_day..(now - 1.day).end_of_day
    when "thisweek"
      now.beginning_of_week..now.end_of_week
    when "thismonth"
      now.beginning_of_month..now.end_of_month
    when "thisyear"
      now.beginning_of_year..now.end_of_year
    when "lastweek"
      (now - 1.week).beginning_of_week..(now - 1.week).end_of_week
    when "lastmonth"
      (now - 1.month).beginning_of_month..(now - 1.month).end_of_month
    when "lastyear"
      (now - 1.year).beginning_of_year..(now - 1.year).end_of_year
    end
  end

  private
    #: (String?) -> String?
    def normalize(string)
      if string
        string.downcase.gsub(/[\s_\-]/, "")
      end
    end
end
