class Cards::ReadingsController < ApplicationController
  include CardScoped

  skip_writer_affinity

  def create
    @notifications = @card.read_by(Current.user)
    record_board_access
  end

  def destroy
    @notifications = @card.unread_by(Current.user)
    record_board_access
  end

  private
    def record_board_access
      @card.board.accessed_by(Current.user)
    end
end
