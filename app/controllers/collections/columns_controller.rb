class Collections::ColumnsController < ApplicationController
  include ActionView::RecordIdentifier, CollectionScoped

  before_action :set_column, only: [ :show, :update, :destroy ]

  def show
    set_page_and_extract_portion_from @column.cards.active.by_last_activity.with_golden_first
    fresh_when etag: [ @column, @page.records ]
  end

  def create
    @column = @collection.columns.create!(column_params)
  end

  def update
    @column.update!(column_params)
  end

  def destroy
    @column.destroy
  end

  private
    def set_column
      @column = @collection.columns.find(params[:id])
    end

    def column_params
      params.require(:column).permit(:name, :color)
    end
end
