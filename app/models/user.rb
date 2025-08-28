class User < ApplicationRecord
  include Accessor, AiQuota, Assignee, Attachable, Mentionable, Named, Role,
    Searcher, SignalUser, Staff, Transferable, Conversational
  include Timelined # Depends on Accessor

  has_one_attached :avatar

  has_many :sessions, dependent: :destroy
  has_secure_password validations: false

  has_many :comments, inverse_of: :creator, dependent: :destroy

  has_many :notifications, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :closures, dependent: :nullify
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card
  has_many :commands, dependent: :destroy
  has_many :push_subscriptions, class_name: "Push::Subscription", dependent: :delete_all
  has_many :period_activity_summaries, dependent: :destroy

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  def deactivate
    sessions.delete_all
    accesses.destroy_all
    SignalId::Database.on_master { signal_user&.destroy }
    update! active: false, email_address: deactived_email_address
  end

  private
    def deactived_email_address
      email_address.sub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end
end
