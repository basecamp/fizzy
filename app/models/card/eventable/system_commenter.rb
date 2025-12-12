class Card::Eventable::SystemCommenter
  include ERB::Util

  attr_reader :card, :event

  def initialize(card, event)
    @card, @event = card, event
  end

  def comment
    return unless comment_body.present?

    card.comments.create! creator: card.account.system_user, body: comment_body, created_at: event.created_at
  end

  private
    def comment_body
      case event.action
      when "card_assigned"
        "#{creator_name} <strong>assigned</strong> this to #{assignee_names}."
      when "card_unassigned"
        "#{creator_name} <strong>unassigned</strong> from #{assignee_names}."
      when "card_closed"
        "<strong>Moved</strong> to “Done” by #{creator_name}"
      when "card_reopened"
        "<strong>Reopened</strong> by #{creator_name}"
      when "card_postponed"
        "#{creator_name} <strong>moved</strong> this to “Not Now”"
      when "card_auto_postponed"
        "<strong>Moved</strong> to “Not Now” due to inactivity"
      when "card_title_changed"
        "#{creator_name} <strong>changed the title</strong> from “#{old_title}” to “#{new_title}”."
      when "card_board_changed"
        "#{creator_name} <strong>moved</strong> this from “#{old_board}” to “#{new_board}”."
      when "card_triaged"
        "#{creator_name} <strong>moved</strong> this to “#{column}”"
      when "card_sent_back_to_triage"
        "#{creator_name} <strong>moved</strong> this back to “Maybe?”"
      end
    end

    def creator_name
      h event.creator.name
    end

    def assignee_names
      h event.assignees.pluck(:name).to_sentence
    end

    def old_title
      h event.particulars.dig("particulars", "old_title")
    end

    def new_title
      h event.particulars.dig("particulars", "new_title")
    end

    def old_board
      h event.particulars.dig("particulars", "old_board")
    end

    def new_board
      h event.particulars.dig("particulars", "new_board")
    end

    def column
      h event.particulars.dig("particulars", "column")
    end
end
