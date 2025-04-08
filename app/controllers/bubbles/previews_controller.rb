class Bubbles::PreviewsController < ApplicationController
  include BucketScoped, FilterScoped

  skip_before_action :set_bucket, only: :index

  before_action :set_filter, only: :index

  def index
    set_page_and_extract_portion_from @filter.bubbles.load_async
  end
end
