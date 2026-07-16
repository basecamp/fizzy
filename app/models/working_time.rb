class WorkingTime
  START_OF_DAY = 9.hours + 30.minutes
  END_OF_DAY = 18.hours + 30.minutes

  class << self
    def minutes_between(start_time, end_time, time_zone: Time.zone)
      return 0 unless start_time && end_time && end_time > start_time

      Time.use_zone(time_zone) do
        start_at = start_time.in_time_zone
        end_at = end_time.in_time_zone

        (start_at.to_date..end_at.to_date).sum do |date|
          working_minutes_on(date, start_at, end_at)
        end
      end
    end

    private
      def working_minutes_on(date, start_at, end_at)
        if date.on_weekend?
          0
        else
          day_start = Time.zone.local(date.year, date.month, date.day) + START_OF_DAY
          day_end = Time.zone.local(date.year, date.month, date.day) + END_OF_DAY
          overlap_start = [ start_at, day_start ].max
          overlap_end = [ end_at, day_end ].min

          [ ((overlap_end - overlap_start) / 60).round, 0 ].max
        end
      end
  end
end
