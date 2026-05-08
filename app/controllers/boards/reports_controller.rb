class Boards::ReportsController < ApplicationController
  include BoardScoped

  def show
    @cards = @board.cards.includes(:assignees, :closure, :tags, :not_now).order(created_at: :desc)
  end
end
