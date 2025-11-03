class Collections::Columns::ClosedsController < ApplicationController
  include CollectionScoped

  def show
    set_page_and_extract_portion_from @collection.cards.closed.recently_closed_first
    fresh_when etag: @page.records
  end
end
