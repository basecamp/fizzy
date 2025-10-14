class Public::Collections::ColumnsController < ApplicationController
  include ActionView::RecordIdentifier, PublicCollectionScoped

  allow_unauthenticated_access only: :show

  layout "public"

  before_action :set_column, only: :show

  def show
    set_page_and_extract_portion_from @column.cards.active.by_last_activity.with_golden_first

    # To enable caching at intermediate proxies during traffic spikes
    expires_in 5.seconds, public: true
  end

  private
    def set_column
      @column = @collection.columns.find(params[:id])
    end
end
