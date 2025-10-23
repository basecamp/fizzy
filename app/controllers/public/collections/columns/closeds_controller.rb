class Public::Collections::Columns::ClosedsController < ApplicationController
  include CachedPublicly, PublicCollectionScoped

  allow_unauthenticated_access only: :show

  layout "public"

  def show
    set_page_and_extract_portion_from @collection.cards.closed.recently_closed_first
  end
end
