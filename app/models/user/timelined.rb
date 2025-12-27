# rbs_inline: enabled

module User::Timelined
  extend ActiveSupport::Concern

  included do
    has_many :accessible_events, through: :boards, source: :events
  end

  def timeline_for(day, filter:)
    User::DayTimeline.new(self, day, filter)
  end
end
