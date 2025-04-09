class FiltersController < ApplicationController
  before_action :set_filter, only: :destroy

  def create
    @filter = Current.user.filters.remember filter_params
    redirect_to cards_path(@filter.as_params)
  end

  def destroy
    @filter.destroy!
    redirect_after_destroy
  end

  private
    def set_filter
      @filter = Current.user.filters.find params[:id]
    end

    def filter_params
      params.permit(*Filter::PERMITTED_PARAMS).compact_blank
    end

    def redirect_after_destroy
      if request.referer == root_url
        redirect_to root_path
      else
        redirect_to cards_path(@filter.as_params)
      end
    end
end
