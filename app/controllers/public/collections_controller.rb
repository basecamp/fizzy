class Public::CollectionsController < ApplicationController
  include CachedPublicly, PublicCollectionScoped

  allow_unauthenticated_access only: :show
  allow_unauthorized_access only: :show

  layout "public"

  def show
    set_page_and_extract_portion_from @collection.cards.awaiting_triage.latest.with_golden_first
  end
end
