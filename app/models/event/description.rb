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
        tag.span(I18n.t("events.creator_you"), data: { only_visible_to_you: true }) +
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
      I18n.t("events.descriptions.comment_created", creator: creator, card_title: card_title)
    end

    def action_sentence(creator, card_title)
      case event.action
      when "card_assigned"
        assigned_sentence(creator, card_title)
      when "card_unassigned"
        unassigned_sentence(creator, card_title)
      when "card_published"
        I18n.t("events.descriptions.card_published", creator: creator, card_title: card_title)
      when "card_closed"
        I18n.t("events.descriptions.card_closed", creator: creator, card_title: card_title, column: I18n.t("columns.done"))
      when "card_reopened"
        I18n.t("events.descriptions.card_reopened", creator: creator, card_title: card_title)
      when "card_postponed"
        I18n.t("events.descriptions.card_postponed", creator: creator, card_title: card_title, column: I18n.t("columns.not_now"))
      when "card_auto_postponed"
        I18n.t("events.descriptions.card_auto_postponed", card_title: card_title, column: I18n.t("columns.not_now"))
      when "card_resumed"
        I18n.t("events.descriptions.card_resumed", creator: creator, card_title: card_title)
      when "card_title_changed"
        renamed_sentence(creator, card_title)
      when "card_board_changed", "card_collection_changed"
        moved_sentence(creator, card_title)
      when "card_triaged"
        triaged_sentence(creator, card_title)
      when "card_sent_back_to_triage"
        I18n.t("events.descriptions.card_sent_back_to_triage", creator: creator, card_title: card_title, column: I18n.t("columns.maybe"))
      end
    end

    def assigned_sentence(creator, card_title)
      if event.assignees.include?(user)
        I18n.t("events.descriptions.assigned_to_you", creator: creator, card_title: card_title)
      else
        I18n.t("events.descriptions.assigned", creator: creator, assignees: h(event.assignees.pluck(:name).to_sentence), card_title: card_title)
      end
    end

    def unassigned_sentence(creator, card_title)
      assignees_text = event.assignees.include?(user) ? I18n.t("events.creator_yourself") : event.assignees.pluck(:name).to_sentence
      I18n.t("events.descriptions.unassigned", creator: creator, assignees: h(assignees_text), card_title: card_title)
    end

    def renamed_sentence(creator, card_title)
      old_title = event.particulars.dig("particulars", "old_title")
      I18n.t("events.descriptions.renamed", creator: creator, card_title: card_title, old_title: h(old_title))
    end

    def moved_sentence(creator, card_title)
      new_location = event.particulars.dig("particulars", "new_board") || event.particulars.dig("particulars", "new_collection")
      I18n.t("events.descriptions.moved", creator: creator, card_title: card_title, new_location: h(new_location))
    end

    def triaged_sentence(creator, card_title)
      column = event.particulars.dig("particulars", "column")
      I18n.t("events.descriptions.triaged", creator: creator, card_title: card_title, column: h(column))
    end
end
