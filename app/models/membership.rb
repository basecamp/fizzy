class Membership < UntenantedRecord
  belongs_to :identity, touch: true
  has_many :magic_links, dependent: :delete_all

  # I want this to be `belongs_to :user`, but ActiveRecord::Tenanted doesn't yet support
  # associations from untenanted to untenanted models.
  #
  # See https://github.com/basecamp/activerecord-tenanted/issues/201
  #
  # In the meantime, when creating a Membership, specify both `user_id` and `user_tenant` attributes.
  def user
    User.with_tenant(user_tenant) { User.find_by(id: user_id) }
  end

  def account
    Account.with_tenant(user_tenant) { Account.sole }
  end

  def send_magic_link
    magic_link = magic_links.create!
    MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
  end
end
