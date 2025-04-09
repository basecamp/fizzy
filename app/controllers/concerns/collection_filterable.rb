module BucketFilterable
  extend ActiveSupport::Concern

  included do
    before_action :set_bucket_filter
  end

  private
    def set_bucket_filter
      params[:bucket_ids] ||= cookies[:bucket_filter]&.split(",") unless params[:clear_filter]
    end

    def bucket_filter
      params[:bucket_ids].presence || Current.user.bucket_ids
    end

    def update_bucket_filter
      if params[:clear_filter]
        cookies.delete(:bucket_filter)
      elsif params[:bucket_ids].present?
        cookies[:bucket_filter] = params[:bucket_ids].join(",")
      end
    end
end
