class Public::Collections::ColumnsController < ApplicationController
  include ActionView::RecordIdentifier, CachedPublicly, PublicCollectionScoped

  allow_unauthenticated_access only: :show

  layout "public"

  before_action :set_column, only: :show

  def show
    set_page_and_extract_portion_from @column.cards.active.by_last_activity.with_golden_first
  end

  private
    def set_column
      @column = @collection.columns.find(params[:id])
    end
end
