class User < ApplicationRecord
  include Accessor, Assignee, Attachable, Configurable,
    Mentionable, Named, Notifiable, Role, Searcher, Watcher
  include Timelined # Depends on Accessor

  self.ignored_columns = %i[ password_digest ]

  has_one_attached :avatar

  belongs_to :membership, optional: true

  has_one :identity, through: :membership, disable_joins: true

  has_many :comments, inverse_of: :creator, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :closures, dependent: :nullify
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  delegate :staff?, to: :identity, allow_nil: true

  def deactivate
    accesses.destroy_all
    update! active: false
  end
end
