class EventSummary < ApplicationRecord
  include Messageable, EventsHelper

  has_many :events, -> { chronologically }, dependent: :delete_all, inverse_of: :summary

  # FIXME: Consider persisting the body and compute at write time.
  def body
    "#{main_summary} #{boosts_summary}".squish
  end

  private
    delegate :time_ago_in_words, to: "ApplicationController.helpers"

    def main_summary
      events.non_boosts.map { |event| summarize(event) }.join(" ")
    end

    def summarize(event)
      ApplicationController.helpers.summarize_event(event)
    end

    def boosts_summary
      if tally = events.boosts.group(:creator).count.presence
        tally.map do |creator, count|
          "#{creator.name} +#{count}"
        end.to_sentence + "."
      end
    end
end
