module Card::LimitedPublishing
  extend ActiveSupport::Concern

  included do
    include Card::Limited

    before_action :ensure_under_limits, only: %i[ create ]
  end
end
