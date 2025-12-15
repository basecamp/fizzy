class User < ApplicationRecord
  include Accessor, Assignee, Attachable, Configurable, EmailAddressChangeable,
    Mentionable, Named, Notifiable, Role, Searcher, Watcher
  include Timelined # Depends on Accessor

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 256, 256 ]
  end

  belongs_to :account
  belongs_to :identity, optional: true

  has_many :comments, inverse_of: :creator, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :closures, dependent: :nullify
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card
  has_many :exports, class_name: "Account::Export", dependent: :destroy

  scope :with_avatars, -> { preload(:account, :avatar_attachment) }

  # Deactivates the user within this account while preserving the identity link.
  #
  # The identity reference is intentionally kept so that:
  #   1. Identity#destroy triggers this via `dependent: :nullify` (which severs the link)
  #   2. UsersController#destroy preserves the link, allowing reactivation if the
  #      user rejoins via join code (see Identity::Joinable#join)
  def deactivate
    accesses.destroy_all
    update! active: false
    close_remote_connections
  end

  def setup?
    name != identity.email_address
  end

  def verified?
    verified_at.present?
  end

  def verify
    update!(verified_at: Time.current) unless verified?
  end

private
    def close_remote_connections
      ActionCable.server.remote_connections.where(current_user: self).disconnect(reconnect: false)
    end
end
