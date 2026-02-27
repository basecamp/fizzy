class Notification::EventPayload < Notification::DefaultPayload
  include ExcerptHelper

  def title
    case event.action
    when "comment_created"
      "RE: #{card_title}"
    else
      card_title
    end
  end

  def body
    case event.action
    when "comment_created"
      format_excerpt(event.eventable.body, length: 200)
    when "card_assigned"
      "Assigned to you by #{event.creator.name}"
    when "card_published"
      "Added by #{event.creator.name}"
    when "card_closed"
      card.closure ? "Moved to Done by #{event.creator.name}" : "Closed by #{event.creator.name}"
    when "card_reopened"
      "Reopened by #{event.creator.name}"
    when "card_triaged"
      if column_name.present?
        "Moved to #{column_name} by #{event.creator.name}"
      else
        "Moved by #{event.creator.name}"
      end
    when "card_sent_back_to_triage"
      "Moved back to Maybe? by #{event.creator.name}"
    when "card_board_changed", "card_collection_changed"
      if new_location_name.present?
        "Moved to #{new_location_name} by #{event.creator.name}"
      else
        "Moved by #{event.creator.name}"
      end
    when "card_title_changed"
      if new_title.present?
        "Renamed to #{new_title} by #{event.creator.name}"
      else
        "Renamed by #{event.creator.name}"
      end
    when "card_postponed"
      "Moved to Not Now by #{event.creator.name}"
    when "card_auto_postponed"
      "Moved to Not Now due to inactivity"
    else
      "Updated by #{event.creator.name}"
    end
  end

  def url
    case event.action
    when "comment_created"
      card_url_with_comment_anchor(event.eventable)
    else
      card_url(card)
    end
  end

  def category
    case event.action
    when "card_assigned" then "assignment"
    when "comment_created" then "comment"
    else "card"
    end
  end

  def high_priority?
    event.action.card_assigned?
  end

  private
    def event
      notification.source
    end

    def card_title
      card.title.presence || "Card #{card.number}"
    end

    def column_name
      event.particulars.dig("particulars", "column")
    end

    def new_location_name
      event.particulars.dig("particulars", "new_board") ||
        event.particulars.dig("particulars", "new_collection")
    end

    def new_title
      event.particulars.dig("particulars", "new_title")
    end

    def card_url_with_comment_anchor(comment)
      Rails.application.routes.url_helpers.card_url(
        comment.card,
        anchor: ActionView::RecordIdentifier.dom_id(comment),
        **url_options
      )
    end
end
