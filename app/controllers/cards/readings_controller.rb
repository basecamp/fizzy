class Cards::ReadingsController < ApplicationController
  include CardScoped

  def create
    @notification = @card.read_by(Current.user)
    record_board_access
  end

  def destroy
    @notification = @card.unread_by(Current.user)
    record_board_access
  end

  private
    def record_board_access
      @card.board.accessed_by(Current.user)
    end
end
