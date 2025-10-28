module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_user_can_access_account, if: -> { ApplicationRecord.current_tenant }
  end

  class_methods do
    def require_access_without_a_user(**options)
      skip_before_action :ensure_user_can_access_account, **options
      before_action :redirect_existing_user, **options
    end
  end

  private
    def ensure_can_administer
      head :forbidden unless Current.user.admin?
    end

    def ensure_is_staff_member
      head :forbidden unless Current.user.staff?
    end

    def ensure_user_can_access_account
      if Current.membership.blank?
        redirect_to session_menu_url(script_name: nil)
      elsif Current.user.nil? && Current.membership.join_code.present?
        redirect_to new_user_path
      elsif !Current.user&.active?
        redirect_to unlink_membership_url(script_name: nil, membership_id: Current.membership.signed_id(purpose: :unlinking))
      end
    end

    def redirect_existing_user
      redirect_to root_path if Current.user
    end

    def account_entry_url(membership)
      if !ApplicationRecord.tenant_exists?(membership.tenant)
      elsif membership.user.blank?
        # We are joining an account. This means the user doesn't yet exist and
        # we have to create it
        new_user_url(script_name: "/#{membership.tenant}", membership: membership.to_signed(for: :user_creation))
        # The user exists, but was deactivated, we want to remove the membership
        unlink_membership_url(script_name: nil, membership: membership.to_signed(for: :unlinking))
      else
        # Everything is fine, let the user enter the account
        root_url(script_name: "/#{membership.tenant}")
      end
    end
end
