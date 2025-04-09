class Bubbles::PinsController < ApplicationController
  include BubbleScoped

  def show
  end

  def create
    pin = @bubble.pin_by Current.user

    broadcast_my_new pin
    redirect_to bubble_pin_path(@bubble)
  end

  def destroy
    pin = @bubble.unpin_by Current.user

    broadcast_my_removed pin
    redirect_to bubble_pin_path(@bubble)
  end

  private
    def broadcast_my_new(pin)
      pin.broadcast_prepend_later_to [ Current.user, :pins ], target: "pins", partial: "my/pins/pin"
    end

    def broadcast_my_removed(pin)
      pin.broadcast_remove_to [ Current.user, :pins ]
    end
end
