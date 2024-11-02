class ViewsController < ApplicationController
  before_action :set_bucket, only: :create
  before_action :set_view, only: :destroy

  def index
    @views = Current.user.views.reverse_chronologically
    fresh_when @views
  end

  def create
    @view = Current.user.views.create_or_find_by!(bucket: @bucket, filters: filter_params).tap(&:touch)
    redirect_to bubbles_path(view_id: @view)
  end

  def destroy
    @view.destroy!
    redirect_after_destroy
  end

  private
    def set_bucket
      @bucket = Current.user.buckets.find(params[:bucket_id]) if params[:bucket_id].present?
    end

    def set_view
      @view = Current.user.views.find(params[:id])
    end

    def filter_params
      helpers.view_filter_params.to_h.except(:bucket_id).compact
    end

    def redirect_after_destroy
      if request.referer == views_url
        redirect_to views_path
      else
        redirect_to bubbles_path(@view.to_params)
      end
    end
end
