class Public::Collections::Columns::StreamsController < ApplicationController
  include CachedPublicly, PublicCollectionScoped

  allow_unauthenticated_access only: :show

  layout "public"

  def show
    set_page_and_extract_portion_from @collection.cards.awaiting_triage.by_last_activity.with_golden_first
  end
end
