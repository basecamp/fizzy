module Identity::SingleSignOnLinkable
  extend ActiveSupport::Concern

  included do
    has_many :single_sign_on_links, dependent: :delete_all
  end

  class_methods do
    def find_by_single_sign_on(claims)
      Identity::SingleSignOnLink.find_by(issuer: claims.issuer, subject: claims.subject)&.identity
    end
  end

  def single_sign_on_linked?
    single_sign_on_links.exists?
  end

  def single_sign_on_link_for(issuer)
    single_sign_on_links.find_by(issuer: issuer)
  end

  def link_single_sign_on(claims)
    single_sign_on_links.create!(issuer: claims.issuer, subject: claims.subject)
  end

  def join_accounts_joinable_by_single_sign_on(name: nil, groups: [])
    Account.joinable_by_single_sign_on(groups).where.not(id: users.select(:account_id)).find_each do |account|
      join account, name: name, verified_at: Time.current
    end
  end

  # Provider groups decide every role except owner, so a change in Fizzy lasts until the next sign-in.
  def update_roles_from_single_sign_on(groups)
    users.active.where.not(role: :owner).includes(:account).find_each do |user|
      user.update!(role: user.account.single_sign_on_role_for(groups))
    end
  end
end
