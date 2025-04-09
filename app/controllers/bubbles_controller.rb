require "ostruct"

class BubblesController < ApplicationController
  include BucketScoped, FilterScoped

  skip_before_action :set_bucket, only: :index

  before_action :set_bubble, only: %i[ show edit update destroy ]
  before_action :handle_display_count, only: :index

  DISPLAY_COUNT_OPTIONS = [ 6, 12, 18, 24 ].freeze
  DEFAULT_DISPLAY_COUNT = 6
  PAGE_SIZE = 50

  def index
    @considering = page_and_filter_for @filter.with(engagement_status: "considering"), per_page: PAGE_SIZE
    @doing = page_and_filter_for @filter.with(engagement_status: "doing"), per_page: PAGE_SIZE
    @popped = page_and_filter_for @filter.with(indexed_by: "popped"), per_page: PAGE_SIZE
  end

  def create
    redirect_to @bucket.bubbles.create!
  end

  def show
  end

  def edit
  end

  def destroy
    @bubble.destroy!
    redirect_to bubbles_path(bucket_ids: [ @bubble.bucket ]), notice: deleted_notice
  end

  def update
    @bubble.update! bubble_params
    redirect_to @bubble
  end

  private
    def set_bubble
      @bubble = @bucket.bubbles.find params[:id]
    end

    def page_and_filter_for(filter, per_page: nil)
      OpenStruct.new \
        page: GearedPagination::Recordset.new(filter.bubbles, per_page:).page(1),
        filter: filter
    end

    def bubble_params
      params.expect(bubble: [ :status, :title, :color, :due_on, :image, :draft_comment, tag_ids: [] ])
    end

    def deleted_notice
      "Bubble deleted" unless @bubble.creating?
    end

    def handle_display_count
      if params[:set_display_count].present?
        cookies[:display_count] = params[:set_display_count]
        redirect_to bubbles_path(
          params.permit(*Filter::PERMITTED_PARAMS, :bucket_ids).except(:set_display_count)
        )
      end
    end

    def display_count
      (cookies[:display_count] || DEFAULT_DISPLAY_COUNT).to_i
    end
end
