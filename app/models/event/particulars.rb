module Event::Particulars
  extend ActiveSupport::Concern

  included do
    store_accessor :particulars, :assignee_ids
  end

  def assignees
    @assignees ||= User.where id: assignee_ids
  end

  def api_particulars
    nested = particulars.dig("particulars") || {}

    case action.to_s
    when "card_assigned", "card_unassigned"
      { "assignee_ids" => Array(assignee_ids) }
    when "card_board_changed"
      { "old_board" => nested["old_board"].to_s, "new_board" => nested["new_board"].to_s }
    when "card_title_changed"
      { "old_title" => nested["old_title"].to_s, "new_title" => nested["new_title"].to_s }
    when "card_triaged"
      { "column" => nested["column"].to_s }
    else
      {}
    end
  end
end
