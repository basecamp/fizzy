class BubblesController < ApplicationController
  include BucketScoped

  skip_before_action :set_bucket, only: :index

  before_action :set_filter, only: :index
  before_action :set_bubble, only: %i[ show edit update destroy ]

  def index
    @bubbles = @filter.bubbles
  end

  def create
    @bubble = @bucket.bubbles.create!
    redirect_to bucket_bubble_path(@bubble.bucket, @bubble, editing: true)
  end

  def show
    fresh_when etag: @bubble
  end

  def edit
  end

  def destroy
    @bubble.destroy!
    redirect_to bubbles_path, notice: "Bubble deleted"
  end

  def update
    @bubble.update! bubble_params
    redirect_to @bubble
  end

  private
    def set_filter
      @filter = Current.user.filters.from_params params.permit(*Filter::PERMITTED_PARAMS)
    end

    def set_bubble
      @bubble = @bucket.bubbles.find params[:id]
    end

    def bubble_params
      params.expect(bubble: [ :title, :color, :due_on, :image, tag_ids: [] ])
    end
end
