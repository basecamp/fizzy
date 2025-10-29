class Public::CardsController < ApplicationController
  include PublicCardScoped

  allow_unauthenticated_access only: :show
  allow_unauthorized_access only: :show

  layout "public"

  def show
    # To enable caching at intermediate proxies during traffic spikes
    expires_in 5.seconds, public: true
  end
end
