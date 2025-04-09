class Collections::InvolvementsController < ApplicationController
  include CollectionScoped

  def update
    @collection.access_for(Current.user).update!(involvement: params[:involvement])
  end
end
