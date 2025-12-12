class Identity < ApplicationRecord
  include Joinable, Transferable

  has_many :access_tokens, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :users, dependent: :nullify
  has_many :accounts, through: :users

  has_one_attached :avatar

  before_destroy :deactivate_users, prepend: true

  # Validate email format only if email_address is present
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  normalizes :email_address, with: ->(value) { value.strip.downcase.presence }
  
  # For local authentication without email
  validates :username, presence: true, uniqueness: true, if: -> { email_address.blank? }
  validates :username, format: { with: /\A[a-zA-Z0-9_]+\z/, message: "only allows letters, numbers, and underscores" }, if: -> { username.present? }
  normalizes :username, with: ->(value) { value.strip.downcase.presence }
  
  # At least one identifier must be present
  validate :email_or_username_present
  
  private
  
  def email_or_username_present
    if email_address.blank? && username.blank?
      errors.add(:base, "Either email address or username must be present")
    end
  end

  def self.find_by_permissable_access_token(token, method:)
    if (access_token = AccessToken.find_by(token: token)) && access_token.allows?(method)
      access_token.identity
    end
  end

  def send_magic_link(**attributes)
    attributes[:purpose] = attributes.delete(:for) if attributes.key?(:for)

    magic_links.create!(attributes).tap do |magic_link|
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    end
  end
  
  # Returns the primary identifier (email or username)
  def identifier
    email_address.presence || username
  end
  
  # Check if this is a local (username-based) account
  def local_account?
    email_address.blank? && username.present?
  end

  private
    def deactivate_users
      users.find_each(&:deactivate)
    end
end
