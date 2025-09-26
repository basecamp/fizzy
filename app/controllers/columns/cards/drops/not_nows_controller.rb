class Columns::Cards::Drops::NotNowsController < ApplicationController
  include CardScoped

  def create
    @card.postpone

    render turbo_stream: turbo_stream.replace("not-now", partial: "collections/show/not_now", method: :morph, locals: { collection: @card.collection })
  end
end
