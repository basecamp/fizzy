class EventSummary < ApplicationRecord
  include Messageable

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
      case event.action
      when "published"
        "Added by #{event.creator.name}."
      when "assigned"
        "Assigned to #{event.assignees.pluck(:name).to_sentence}."
      when "unassigned"
        "Unassigned from #{event.assignees.pluck(:name).to_sentence}."
      when "staged"
        "#{event.creator.name} moved this to '#{event.stage_name}'."
      when "closed"
        "Closed by #{ event.creator.name }"
      when "unstaged"
        "#{event.creator.name} removed this from '#{event.stage_name}'."
      when "due_date_added"
        "#{event.creator.name} set due date to #{event.particulars.dig('particulars', 'due_date').to_date.strftime('%B %-d')}."
      when "due_date_changed"
        "#{event.creator.name} changed due date to #{event.particulars.dig('particulars', 'due_date').to_date.strftime('%B %-d')}."
      when "due_date_removed"
        "#{event.creator.name} removed the date."
      when "title_changed"
        "#{event.creator.name} changed title from '#{event.particulars.dig('particulars', 'old_title')}' to '#{event.particulars.dig('particulars', 'new_title')}'."
      end
    end

    def boosts_summary
      if tally = events.boosts.group(:creator).count.presence
        tally.map do |creator, count|
          "#{creator.name} +#{count}"
        end.to_sentence + "."
      end
    end
end
