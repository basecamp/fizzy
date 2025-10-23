class Public::Collections::Columns::NotNowsController < ApplicationController
  include CachedPublicly, PublicCollectionScoped

  allow_unauthenticated_access only: :show

  layout "public"

  def show
    set_page_and_extract_portion_from @collection.cards.postponed.reverse_chronologically.with_golden_first
  end
end
