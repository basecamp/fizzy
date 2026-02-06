module Card::Limited
  extend ActiveSupport::Concern

  private
    def ensure_under_limits
      head :forbidden if Current.account.exceeding_limits?
    end
end
