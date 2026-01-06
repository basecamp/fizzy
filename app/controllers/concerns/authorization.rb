module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_can_access_account, if: :authenticated_account_access?
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
      head :forbidden unless Current.identity.staff?
    end

    def authenticated_account_access?
      Current.account.present? && authenticated?
    end

    def ensure_can_access_account
      unless account_accessible? && user_active?
        respond_to do |format|
          format.html { redirect_to session_menu_path(script_name: nil) }
          format.json { head :forbidden }
        end
      end
    end

    def account_accessible?
      Current.account.active?
    end

    def user_active?
      Current.user&.active?
    end

    def redirect_existing_user
      redirect_to root_path if Current.user
    end
end
