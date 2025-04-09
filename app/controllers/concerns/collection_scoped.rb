module CollectionScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_collection
  end

  private
    def set_collection
      @collection = Current.user.collections.find(params[:collection_id])
    end
end
