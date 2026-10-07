class User < ApplicationRecord
  include Accessor, Assignee, Attachable, Avatar, Configurable, EmailAddressChangeable,
    Mentionable, Named, Notifiable, Role, Searcher, Watcher
  include Timelined # Depends on Accessor

  belongs_to :account
  belongs_to :identity, optional: true

  validates :name, presence: true

  has_many :comments, inverse_of: :creator, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :closures, dependent: :nullify
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card
  has_many :data_exports, class_name: "User::DataExport", dependent: :destroy

  def deactivate
    transaction do
      accesses.destroy_all
      # Once detached from the identity, the user is out of reach of its OAuth
      # grants, so the apps' own push subscriptions end here. The grant-side
      # cleanup can't find this user after the identity is cleared.
      push_subscriptions.owned_by_apps.delete_all
      update! active: false, identity: nil
      close_remote_connections
    end
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

  def close_remote_connections(reconnect: false)
    ActionCable.server.remote_connections.where(current_user: self).disconnect(reconnect:)
  end
end
