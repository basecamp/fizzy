class Searches::QueriesController < ApplicationController
  def create
    Current.user.remember_search(params[:q])
    head :ok
  end
end
