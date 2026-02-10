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
    else
      event.creator.name
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

    def card_url_with_comment_anchor(comment)
      Rails.application.routes.url_helpers.card_url(
        comment.card,
        anchor: ActionView::RecordIdentifier.dom_id(comment),
        **url_options
      )
    end
end
