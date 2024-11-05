class User < ApplicationRecord
  belongs_to :account

  has_many :sessions, dependent: :destroy
  has_secure_password validations: false

  has_many :accesses, dependent: :destroy
  has_many :buckets, through: :accesses
  has_many :accessible_bubbles, through: :buckets, source: :bubbles

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy

  has_many :pops, dependent: :nullify

  has_many :assignments, foreign_key: :assignee_id, dependent: :destroy
  has_many :assignings, foreign_key: :assigner_id, class_name: "Assignment"
  has_many :assigned_bubbles, through: :assignments, source: :bubble

  has_one_attached :avatar

  validates_presence_of :email_address
  normalizes :email_address, with: ->(value) { value.strip.downcase }

  scope :active, -> { where(active: true) }
  scope :alphabetically, -> { order("LOWER(name)") }

  def initials
    name.to_s.scan(/\b\p{L}/).join.upcase
  end

  def deactivate
    transaction do
      sessions.destroy_all
      accesses.destroy_all
      update! active: false, email_address: deactived_email_address
    end
  end

  def can_remove?(other)
    other != self
  end

  private
    def deactived_email_address
      email_address.sub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end
end
