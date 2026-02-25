class My::PinsController < ApplicationController
  def index
    @pins = user_pins
    fresh_when etag: [ @pins, @pins.collect(&:card) ]
  end

  private
    def user_pins
      Current.user.pins.includes(:card).ordered.limit(pins_limit)
    end

    def pins_limit
      request.format.json? ? 100 : 20
    end
end
