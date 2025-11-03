class Collections::PublicationsController < ApplicationController
  include CollectionScoped

  def create
    @collection.publish
  end

  def destroy
    @collection.unpublish
    @collection.reload
  end
end
