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

  def deactivate
    transaction do
      accesses.destroy_all
      update! active: false, identity: nil
      close_remote_connections
    end
  end

  def setup?
    name != identity.email_address
  end

  private
    def close_remote_connections
      ActionCable.server.remote_connections.where(current_user: self).disconnect(reconnect: false)
    end
end
