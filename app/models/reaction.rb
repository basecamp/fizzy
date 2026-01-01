class Reaction < ApplicationRecord
  belongs_to :account, default: -> { comment.account }
  belongs_to :comment, touch: true
  belongs_to :reacter, class_name: "User", default: -> { Current.user }

  scope :ordered, -> { order(:created_at) }

  after_create :register_card_activity

  delegate :all_emoji?, to: :content

  private
    def register_card_activity
      comment.card.touch_last_active_at
    end
end
