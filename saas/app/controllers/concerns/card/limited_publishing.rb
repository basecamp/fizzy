module Card::LimitedPublishing
  extend ActiveSupport::Concern

  included do
    before_action :ensure_can_publish_cards, only: %i[ create ]
  end

  private
    def ensure_can_publish_cards
      head :forbidden if Current.account.exceeding_card_limit?
    end
end
