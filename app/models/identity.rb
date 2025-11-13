class Identity < ApplicationRecord
  include Joinable, Transferable

  has_many :magic_links, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :users, dependent: :nullify
  has_many :accounts, through: :users

  has_one_attached :avatar

  before_destroy :deactivate_users

  normalizes :email_address, with: ->(value) { value.strip.downcase.presence }

  def send_magic_link
    magic_links.create!.tap do |magic_link|
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    end
  end

  def staff?
    email_address.ends_with?("@37signals.com") || email_address.ends_with?("@basecamp.com")
  end

  private
    def deactivate_users
      users.find_each(&:deactivate)
    end
end
