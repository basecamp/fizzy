class Identity < UntenantedRecord
  has_many :memberships, dependent: :destroy
  has_many :magic_links, dependent: :delete_all

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  class << self
    def link(email_address:, to:)
      find_or_create_by!(email_address: email_address).tap { |identity| identity.link_to(to) }
    end

    def unlink(email_address:, from:)
      find_by(email_address: email_address)&.unlink_from(from)
    end
  end

  def send_magic_link
    magic_links.create!.tap do |magic_link|
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    end
  end

  def link_to(tenant)
    memberships.find_or_create_by!(tenant: tenant) do |membership|
      membership.account_name = ApplicationRecord.with_tenant(membership.tenant) { Account.sole.name }
    end
  end

  def unlink_from(tenant)
    memberships.find_by(tenant: tenant)&.destroy
  end
end
