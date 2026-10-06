class Session < ApplicationRecord
  belongs_to :identity

  serialize :single_sign_on_groups, type: Array, coder: JSON

  def recently_authenticated_by_single_sign_on?
    single_sign_on_authenticated_at.present? &&
      single_sign_on_authenticated_at > SingleSignOn.reauthentication_period.ago
  end

  def single_sign_on_group?(group)
    SingleSignOn.member?(single_sign_on_groups, group)
  end

  def single_sign_on_admin?
    SingleSignOn.admin?(single_sign_on_groups)
  end

  def single_sign_on_account_creator?
    SingleSignOn.account_creator?(single_sign_on_groups)
  end
end
