class Cards::DraftsController < ApplicationController
  include CardScoped

  before_action :redirect_if_published

  def show
  end

  private
    def redirect_if_published
      redirect_to @card unless @card.drafted?
    end
end
