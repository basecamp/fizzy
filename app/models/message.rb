class Message < ApplicationRecord
  belongs_to :card, touch: true

  delegated_type :messageable, types: Messageable::TYPES, inverse_of: :message, dependent: :destroy

  scope :chronologically, -> { order created_at: :asc, id: :desc }

  after_create :created
  after_destroy :destroyed

  private
    def created
      card.comment_created(comment) if comment?
    end

    def destroyed
      card.comment_destroyed if comment?
    end
end
