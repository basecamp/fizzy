class Boards::ReportsController < ApplicationController
  include BoardScoped

  def show
    @selected_assignee_ids = Array(params[:assignee_ids])
    @date_preset            = params[:date_preset].presence || "all"
    @date_from              = params[:date_from]
    @date_to                = params[:date_to]
    @active_view            = params[:view].presence || "table"

    base_cards = @board.cards
      .includes(:assignees, :closure, :tags, :not_now, :creator)
      .order(created_at: :desc)

    @cards = filter_cards(base_cards.to_a)

    @events = @board.events
      .where(eventable_type: "Card", action: %w[card_published card_closed comment_created])
      .includes(:creator, eventable: [ :closure, :creator ])
      .order(created_at: :desc)
      .limit(200)

    @board_assignees = User
      .joins("INNER JOIN assignments ON assignments.assignee_id = users.id")
      .joins("INNER JOIN cards ON cards.id = assignments.card_id")
      .where(cards: { board_id: @board.id })
      .select("users.id, users.name")
      .distinct
      .order("users.name")

    closed_cards = @cards.select(&:closed?)
    cycle_hours  = closed_cards.filter_map do |c|
      (c.closed_at - c.created_at) / 3600.0 if c.closed_at
    end

    @kpi_scope     = @cards.size
    @kpi_completed = closed_cards.size
    @kpi_in_flight = @cards.size - closed_cards.size
    @kpi_avg_cycle = cycle_hours.any? ? cycle_hours.sum / cycle_hours.size : nil
  end

  private
    def filter_cards(cards)
      if @selected_assignee_ids.any?
        cards = cards.select do |c|
          c.assignees.any? { |a| @selected_assignee_ids.include?(a.id) }
        end
      end

      unless @date_preset == "all"
        if @date_preset == "custom"
          from = safe_date(@date_from)&.beginning_of_day
          to   = safe_date(@date_to)&.end_of_day
          cards = cards.select do |c|
            ref = c.closed_at || c.created_at
            (from.nil? || ref >= from) && (to.nil? || ref <= to)
          end
        else
          days = { "7" => 7, "14" => 14, "30" => 30, "90" => 90, "sprint" => 14 }[@date_preset]
          if days
            cutoff = days.days.ago
            cards = cards.select { |c| (c.closed_at || c.created_at) >= cutoff }
          end
        end
      end

      cards
    end

    def safe_date(str)
      Date.parse(str) if str.present?
    rescue ArgumentError
      nil
    end
end
