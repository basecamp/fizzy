class Bubbles::PreviewsController < ApplicationController
  include FilterScoped

  before_action :set_filter, only: :index

  def index
    set_page_and_extract_portion_from @filter.bubbles, per_page: BubblesController::PAGE_SIZE
  end
end
