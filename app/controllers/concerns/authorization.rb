module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_can_access_account, if: -> { ApplicationRecord.current_tenant && Current.session }
  end

  class_methods do
    def allow_unauthorized_access(**options)
      skip_before_action :ensure_can_access_account, **options
    end

    def require_access_without_a_user(**options)
      skip_before_action :ensure_can_access_account, **options
      before_action :redirect_existing_user, **options
    end
  end

  private
    def ensure_admin
      head :forbidden unless Current.user.admin?
    end

    def ensure_staff
      head :forbidden unless Current.user.staff?
    end

    def ensure_can_access_account
      if Current.membership.blank?
        redirect_to session_menu_url(script_name: nil)
      elsif Current.user.nil? && Current.membership.join_code.present?
        redirect_to new_users_join_path
      elsif !Current.user&.active?
        redirect_to unlink_membership_url(script_name: nil, membership_id: Current.membership.signed_id(purpose: :unlinking))
      end
    end

    def redirect_existing_user
      redirect_to root_path if Current.user
    end
end
