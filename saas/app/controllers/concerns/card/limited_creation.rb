module Card::LimitedCreation
  extend ActiveSupport::Concern

  included do
    include Card::Limited

    # Only limit API requests. We let you create drafts in the app to actually show the banner, no matter the card count.
    # We limit card publications separately. See +Card::LimitedPublishing+.
    before_action :ensure_under_limits, only: %i[ create ], if: -> { request.format.json? }
  end
end
