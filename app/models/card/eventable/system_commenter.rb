class Card::Eventable::SystemCommenter
  attr_reader :card, :event

  def initialize(card, event)
    @card, @event = card, event
  end

  def comment
    return unless comment_body.present?

    card.comments.create! creator: User.system, body: comment_body, created_at: event.created_at
  end

  private
    def comment_body
      case event.action
      when "card_assigned"
        "#{event.creator.name} <strong>assigned</strong> this to #{event.assignees.pluck(:name).to_sentence}."
      when "card_unassigned"
        "#{event.creator.name} <strong>unassigned</strong> from #{event.assignees.pluck(:name).to_sentence}."
      when "card_closed"
        "<strong>Moved</strong> to “Done” by #{event.creator.name}"
      when "card_reopened"
        "<strong>Reopened</strong> by #{event.creator.name}"
      when "card_postponed"
        "#{event.creator.name} <strong>moved</strong> this to “Not Now”"
      when "card_auto_postponed"
        "<strong>Closed</strong> as “Not Now” due to inactivity"
      when "card_title_changed"
        "#{event.creator.name} <strong>changed the title</strong> from “#{event.particulars.dig('particulars', 'old_title')}” to “#{event.particulars.dig('particulars', 'new_title')}”."
      when "card_collection_changed"
      "#{event.creator.name} <strong>moved</strong> this from “#{event.particulars.dig('particulars', 'old_collection')}” to “#{event.particulars.dig('particulars', 'new_collection')}”."
      when "card_triaged"
        "#{event.creator.name} <strong>moved</strong> this to “#{event.particulars.dig('particulars', 'column')}”"
      when "card_sent_back_to_triage"
        "#{event.creator.name} <strong>moved</strong> this back to “Maybe?”"
      end
    end
end
