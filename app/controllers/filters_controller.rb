class FiltersController < ApplicationController
  before_action :set_filter, only: :destroy

  def create
    @filter = Current.user.filters.create_or_find_by!(params: filter_params).tap(&:touch)
    redirect_to bubbles_path(@filter.to_params)
  end

  def destroy
    @bucket.destroy!
    redirect_after_destroy
  end

  private
    def set_filter
      @bucket = Current.user.buckets.filters.find params[:id]
      @filter = @bucket.filter
    end

    def filter_params
      params.permit(*Filter::KNOWN_PARAMS).compact_blank
    end

    def redirect_after_destroy
      if request.referer == root_url
        redirect_to root_path
      else
        redirect_to bubbles_path(@filter.to_params)
      end
    end
end
