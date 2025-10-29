class Public::Collections::Columns::NotNowsController < ApplicationController
  include PublicCollectionScoped

  allow_unauthenticated_access only: :show
  allow_unauthorized_access only: :show

  layout "public"

  def show
    set_page_and_extract_portion_from @collection.cards.postponed.reverse_chronologically.with_golden_first

    # To enable caching at intermediate proxies during traffic spikes
    expires_in 5.seconds, public: true
  end
end
