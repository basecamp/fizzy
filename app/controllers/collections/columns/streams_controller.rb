class Collections::Columns::StreamsController < ApplicationController
  include CollectionScoped

  def show
    set_page_and_extract_portion_from @collection.cards.awaiting_triage.latest.with_golden_first
    fresh_when etag: @page.records
  end
end
