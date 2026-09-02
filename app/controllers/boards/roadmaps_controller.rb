class Boards::RoadmapsController < ApplicationController
  include BoardScoped

  def show
    @roadmap = Board::Roadmap.new(@board)
  end
end
