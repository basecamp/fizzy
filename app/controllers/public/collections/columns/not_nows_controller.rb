class Public::Collections::Columns::NotNowsController < Public::BaseController
  def show
    set_page_and_extract_portion_from @collection.cards.postponed.reverse_chronologically.with_golden_first
  end
end
