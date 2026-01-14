class Cards::PinsController < ApplicationController
  include CardScoped

  def show
    fresh_when etag: @card.pin_for(Current.user) || "none"
  end

  def create
    @pin = @card.pin_by Current.user

    respond_to do |format|
      format.html do
        broadcast_add_pin_to_tray
        render_pin_button_replacement
      end
      format.json { head :no_content }
    end
  end

  def destroy
    @pin = @card.unpin_by Current.user

    respond_to do |format|
      format.html do
        broadcast_remove_pin_from_tray
        render_pin_button_replacement
      end
      format.json { head :no_content }
    end
  end

  private
    def broadcast_add_pin_to_tray
      @pin.broadcast_prepend_to [ Current.user, :pins_tray ], target: "pins", partial: "my/pins/pin"
    end

    def broadcast_remove_pin_from_tray
      @pin.broadcast_remove_to [ Current.user, :pins_tray ]
    end

    def render_pin_button_replacement
      render turbo_stream: turbo_stream.replace([ @card, :pin_button ], partial: "cards/pins/pin_button", locals: { card: @card })
    end
end
