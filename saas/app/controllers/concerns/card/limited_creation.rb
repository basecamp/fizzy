module Card::LimitedCreation
  extend ActiveSupport::Concern

  included do
    # Only limit API requests. We let you create drafts in the app to actually show the banner, no matter the card count.
    # We limit card publications separately. See +Card::LimitedPublishing+.
    before_action :ensure_can_create_cards, only: %i[ create ], if: -> { request.format.json? }
  end

  private
    def ensure_can_create_cards
      head :forbidden if Current.account.exceeding_card_limit?
    end
end
