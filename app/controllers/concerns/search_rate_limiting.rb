module SearchRateLimiting
  extend ActiveSupport::Concern

  SEARCHES_PER_HOUR = 300
  RETRY_AFTER = 1.minute

  class_methods do
    def limit_searches(**options)
      rate_limit to: SEARCHES_PER_HOUR, within: 1.hour, scope: "searches", by: -> { Current.user },
        with: :searches_exceeded, if: :searching_with_access_token?, **options
    end
  end

  private
    def searching_with_access_token?
      Current.session.nil? && Current.user.present? && searching?
    end

    def searches_exceeded
      response.headers["Retry-After"] = RETRY_AFTER.to_i.to_s

      respond_to do |format|
        format.json { render json: { error: "Too many searches. Retry after #{RETRY_AFTER.to_i} seconds." }, status: :too_many_requests }
        format.any { head :too_many_requests }
      end
    end
end
