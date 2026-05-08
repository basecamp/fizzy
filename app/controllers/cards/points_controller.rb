class Cards::PointsController < ApplicationController
  include CardScoped

  def edit
  end

  def update
    @card.update!(points: points_params)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          [ @card, :points ],
          partial: "cards/points/points",
          locals: { card: @card }
        )
      end
    end
  end

  private
    def points_params
      params.require(:card).permit(:points)[:points].presence
    end
end
