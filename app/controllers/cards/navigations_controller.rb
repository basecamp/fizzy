class Cards::NavigationsController < ApplicationController
  include CardScoped

  def show
    navigation = Card::Navigation.new(@card, column_id: params[:column_id])

    render json: { numbers: navigation.numbers, column_id: navigation.column_id, name: navigation.name }
  end
end
