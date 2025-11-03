class Public::CollectionsController < Public::BaseController
  def show
    set_page_and_extract_portion_from @collection.cards.awaiting_triage.latest.with_golden_first
  end
end
