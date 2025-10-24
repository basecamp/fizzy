class User < ApplicationRecord
  include Accessor, AiQuota, Assignee, Attachable, Configurable, Conversational,
    Highlights, Identifiable, Invitable, Mentionable, Named, Notifiable, Role, Searcher, Staff,
    Transferable, Watcher
  include Timelined # Depends on Accessor

  self.ignored_columns = %i[ password_digest ]

  has_one_attached :avatar

  has_many :comments, inverse_of: :creator, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :closures, dependent: :nullify
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  def deactivate
    accesses.destroy_all
    update! active: false
    Identity.unlink(email_address: email_address, from: tenant)
  end
end
