class Public::CardsController < ApplicationController
  include CachedPublicly, PublicCardScoped

  allow_unauthenticated_access only: :show

  layout "public"

  def show
  end
end
