class User < ApplicationRecord
  include Accessor, Assignee, Avatar, Role, Transferable

  belongs_to :account

  has_many :sessions, dependent: :destroy
  has_secure_password validations: false

  has_many :comments, inverse_of: :creator, dependent: :destroy

  has_many :notifications, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :closures, dependent: :nullify
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  scope :alphabetically, -> { order("lower(name)") }

  def initials
    name.to_s.scan(/\b\p{L}/).join.upcase
  end

  def deactivate
    transaction do
      sessions.delete_all
      accesses.destroy_all
      update! active: false, email_address: deactived_email_address
    end
  end

  private
    def deactived_email_address
      email_address.sub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end
end
