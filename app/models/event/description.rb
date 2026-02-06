class Event::Description
  include ActionView::Helpers::TagHelper
  include ERB::Util

  attr_reader :event, :user

  def initialize(event, user)
    @event = event
    @user = user
  end

  def to_html
    to_sentence(creator_tag, card_title_tag).html_safe
  end

  def to_plain_text
    to_sentence(creator_name, quoted(card.title))
  end

  private
    def to_sentence(creator, card_title)
      if event.action.comment_created?
        comment_sentence(creator, card_title)
      else
        action_sentence(creator, card_title)
      end
    end

    def creator_tag
      tag.span data: { creator_id: event.creator.id } do
        tag.span("You", data: { only_visible_to_you: true }) +
        tag.span(event.creator.name, data: { only_visible_to_others: true })
      end
    end

    def card_title_tag
      tag.span card.title, class: "txt-underline"
    end

    def creator_name
      h(event.creator.name)
    end

    def quoted(text)
      %("#{h text}")
    end

    def card
      @card ||= event.action.comment_created? ? event.eventable.card : event.eventable
    end

    def comment_sentence(creator, card_title)
      "#{creator} commented on #{card_title}"
    end

    def action_sentence(creator, card_title)
      case event.action
      when "card_assigned"
        assigned_sentence(creator, card_title)
      when "card_unassigned"
        unassigned_sentence(creator, card_title)
      when "card_published"
        "#{creator} added #{card_title}"
      when "card_closed"
        %(#{creator} moved #{card_title} to "Done")
      when "card_reopened"
        "#{creator} reopened #{card_title}"
      when "card_postponed"
        %(#{creator} moved #{card_title} to "Not Now")
      when "card_auto_postponed"
        %(#{card_title} moved to "Not Now" due to inactivity)
      when "card_resumed"
        "#{creator} resumed #{card_title}"
      when "card_title_changed"
        renamed_sentence(creator, card_title)
      when "card_board_changed", "card_collection_changed"
        moved_sentence(creator, card_title)
      when "card_triaged"
        triaged_sentence(creator, card_title)
      when "card_sent_back_to_triage"
        %(#{creator} moved #{card_title} back to "Maybe?")
      end
    end

    def assigned_sentence(creator, card_title)
      if event.assignees.include?(user)
        "#{creator} will handle #{card_title}"
      else
        "#{creator} assigned #{h event.assignees.pluck(:name).to_sentence} to #{card_title}"
      end
    end

    def unassigned_sentence(creator, card_title)
      assignees_text = event.assignees.include?(user) ? "yourself" : event.assignees.pluck(:name).to_sentence
      "#{creator} unassigned #{h(assignees_text)} from #{card_title}"
    end

    def renamed_sentence(creator, card_title)
      old_title = event.particulars.dig("particulars", "old_title")
      %(#{creator} renamed #{card_title} (was: "#{h old_title}"))
    end

    def moved_sentence(creator, card_title)
      new_location = event.particulars.dig("particulars", "new_board") || event.particulars.dig("particulars", "new_collection")
      %(#{creator} moved #{card_title} to "#{h new_location}")
    end

    def triaged_sentence(creator, card_title)
      column = event.particulars.dig("particulars", "column")
      %(#{creator} moved #{card_title} to "#{h column}")
    end
end
