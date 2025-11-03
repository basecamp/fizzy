class Public::Collections::Columns::ClosedsController < Public::BaseController
  def show
    set_page_and_extract_portion_from @collection.cards.closed.recently_closed_first
  end
end
