class Cards::ReadingsController < ApplicationController
  include CardScoped

  def create
    @notifications = @card.read_by(Current.user)
    record_collection_access
  end

  private
    def record_collection_access
      @card.collection.accessed_by(Current.user)
    end
end
