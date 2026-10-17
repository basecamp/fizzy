module Account::SingleSignOnEnforceable
  extend ActiveSupport::Concern

  included do
    normalizes :single_sign_on_group, with: ->(group) { group.strip.presence }

    validate :single_sign_on_group_is_a_full_path, :single_sign_on_group_fits_its_column

    scope :joinable_by_single_sign_on, ->(groups) do
      if SingleSignOn.admin?(groups)
        active
      else
        active.where(single_sign_on_group: SingleSignOn.groups_with_parents(groups))
      end
    end

    after_update :update_roles_from_single_sign_on, if: -> { saved_change_to_single_sign_on_group? && SingleSignOn.configured? }
    after_update_commit :reconnect_users, if: :saved_change_to_single_sign_on_group?
  end

  def accessible_with?(session)
    if SingleSignOn.configured?
      session.present? && session.recently_authenticated_by_single_sign_on? &&
        (session.single_sign_on_admin? || single_sign_on_group_includes?(session))
    else
      true
    end
  end

  def single_sign_on_group_includes?(session)
    single_sign_on_group.blank? || session.single_sign_on_group?(single_sign_on_group)
  end

  def single_sign_on_admin_group
    if single_sign_on_group && SingleSignOn.account_admin_subgroup
      "#{single_sign_on_group}/#{SingleSignOn.account_admin_subgroup}"
    end
  end

  def single_sign_on_role_for(groups)
    if SingleSignOn.admin?(groups) || (single_sign_on_admin_group && SingleSignOn.member?(groups, single_sign_on_admin_group))
      "admin"
    else
      "member"
    end
  end

  private
    # Provider groups can be nested, so only a full path names one group.
    def single_sign_on_group_is_a_full_path
      if single_sign_on_group.present? && !SingleSignOn.full_group_path?(single_sign_on_group)
        errors.add :base, "Enter the full group path, such as /sales"
      end
    end

    def single_sign_on_group_fits_its_column
      if single_sign_on_group.to_s.length > SingleSignOn::GROUP_LENGTH_LIMIT
        errors.add :base, "Enter a group path of #{SingleSignOn::GROUP_LENGTH_LIMIT} characters or fewer"
      end
    end

    # Sign-in sets roles from groups, so a new group sets them again from the newest sign-in of each person.
    def update_roles_from_single_sign_on
      users.active.where.not(role: :owner).includes(:identity).find_each do |user|
        user.update!(role: single_sign_on_role_for(user.identity.latest_single_sign_on_groups))
      end
    end

    def reconnect_users
      users.active.find_each { |user| user.close_remote_connections(reconnect: true) }
    end
end
