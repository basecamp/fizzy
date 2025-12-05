module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_can_access_account, if: -> { Current.account.present? && authenticated? }
    before_action :ensure_only_staff_can_access_non_production_remote_environments, if: :authenticated?
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

    def ensure_can_access_account
      redirect_to session_menu_url(script_name: nil), allow_other_host: true if Current.user.blank? || !Current.user.active?
    end

    def ensure_only_staff_can_access_non_production_remote_environments
      head :forbidden unless Rails.env.local? || Rails.env.production? || Current.identity.staff?
    end

    def redirect_existing_user
      redirect_to root_path if Current.user
    end
end
