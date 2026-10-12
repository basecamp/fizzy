class Cards::ReadingsController < ApplicationController
  include CardScoped

  skip_before_action :ensure_board_is_active

  def create
    @notification = @card.read_by(Current.user)
    record_board_access

    respond_to do |format|
      format.turbo_stream
      format.json { head :created }
    end
  end

  def destroy
    @notification = @card.unread_by(Current.user)
    record_board_access

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def record_board_access
      @card.board.accessed_by(Current.user)
    end
end
