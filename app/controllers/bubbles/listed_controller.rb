class Bubbles::ListedController < ApplicationController
  include BucketScoped

  skip_before_action :set_bucket, only: :index

  before_action :set_filter, only: :index

  def index

    Rails.logger.info "-" *100
    Rails.logger.info @filter.bubbles.popped.count
    Rails.logger.info "-" *100

    set_page_and_extract_portion_from @filter.bubbles.load_async
  end

  private
    DEFAULT_PARAMS = { indexed_by: "newest" }

    def set_filter
      @filter = Current.user.filters.from_params params.reverse_merge(**DEFAULT_PARAMS).permit(*Filter::PERMITTED_PARAMS)
    end
end
