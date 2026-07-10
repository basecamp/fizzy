class Boards::AccessesController < ApplicationController
  include BoardScoped

  def index
    set_page_and_extract_portion_from @board.account.users.active.alphabetically.includes(:identity)
  end

  private
    def involvement_by_user
      @involvement_by_user ||= @board.accesses.where(user_id: @page.records.map(&:id)).pluck(:user_id, :involvement).to_h
    end

    helper_method :involvement_by_user
end
