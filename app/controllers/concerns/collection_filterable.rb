module CollectionFilterable
  extend ActiveSupport::Concern

  included do
    before_action :set_collection_filter
  end

  private
    def set_collection_filter
      params[:collection_ids] ||= cookies[:collection_filter]&.split(",") unless params[:clear_filter]
    end

    def collection_filter
      params[:collection_ids].presence || Current.user.collection_ids
    end

    def update_collection_filter
      if params[:clear_filter]
        cookies.delete(:collection_filter)
      elsif params[:collection_ids].present?
        cookies[:collection_filter] = params[:collection_ids].join(",")
      end
    end
end
