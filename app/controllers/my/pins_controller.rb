class My::PinsController < ApplicationController
  def index
    @pins = Current.user.pins.includes(:card).ordered.limit(20)
    fresh_when @pins
  end
end
