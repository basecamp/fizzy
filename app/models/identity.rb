class Identity < UntenantedRecord
  include EmailAddressChangeable, Transferable

  has_many :memberships, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(value) { value.strip.downcase }
  validates :email_address, presence: true

  def send_magic_link
    magic_links.create!.tap do |magic_link|
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    end
  end

  def link_to(tenant, context: nil)
    memberships.find_or_create_by!(tenant: tenant) do |membership|
      membership.context = context
    end
  end

  def unlink_from(tenant)
    memberships.find_by(tenant: tenant)&.destroy
  end

  def staff?
    email_address.ends_with?("@37signals.com") || email_address.ends_with?("@basecamp.com")
  end
end
