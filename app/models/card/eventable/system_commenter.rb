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
        I18n.t("events.system_comment.card_assigned_html", creator_name: creator_name, assignee_names: assignee_names).html_safe
      when "card_unassigned"
        I18n.t("events.system_comment.card_unassigned_html", creator_name: creator_name, assignee_names: assignee_names).html_safe
      when "card_closed"
        I18n.t("events.system_comment.card_closed_html", creator_name: creator_name, column: I18n.t("columns.done")).html_safe
      when "card_reopened"
        I18n.t("events.system_comment.card_reopened_html", creator_name: creator_name).html_safe
      when "card_postponed"
        I18n.t("events.system_comment.card_postponed_html", creator_name: creator_name, column: I18n.t("columns.not_now")).html_safe
      when "card_auto_postponed"
        I18n.t("events.system_comment.card_auto_postponed_html", column: I18n.t("columns.not_now")).html_safe
      when "card_title_changed"
        I18n.t("events.system_comment.card_title_changed_html", creator_name: creator_name, old_title: old_title, new_title: new_title).html_safe
      when "card_board_changed"
        I18n.t("events.system_comment.card_board_changed_html", creator_name: creator_name, old_board: old_board, new_board: new_board).html_safe
      when "card_triaged"
        I18n.t("events.system_comment.card_triaged_html", creator_name: creator_name, column: column).html_safe
      when "card_sent_back_to_triage"
        I18n.t("events.system_comment.card_sent_back_to_triage_html", creator_name: creator_name, column: I18n.t("columns.maybe")).html_safe
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
