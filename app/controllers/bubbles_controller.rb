class BubblesController < ApplicationController
  include BucketScoped

  skip_before_action :set_bucket, only: :index

  before_action :set_view, only: :index
  before_action :set_bubble, only: %i[ show edit update ]

  def index
    @bubbles = @view.bubbles
    @bubbles = @bubbles.mentioning(params[:term]) if params[:term].present?
  end

  def new
    @bubble = @bucket.bubbles.build
  end

  def create
    @bubble = @bucket.bubbles.create!
    redirect_to @bubble
  end

  def show
  end

  def edit
  end

  def update
    @bubble.update! bubble_params
    redirect_to @bubble
  end

  private
    def set_view
      @view = Current.user.views.find_or_initialize_by(id: params[:view_id]) do |view|
        view.bucket = set_bucket if params[:bucket_id]
        view.filters = params.permit(*View::KNOWN_FILTERS).except(:bucket_id)
      end
    end

    def set_bubble
      @bubble = @bucket.bubbles.find params[:id]
    end

    def bubble_params
      params.expect(bubble: [ :title, :color, :due_on, :image, tag_ids: [] ])
    end
end
