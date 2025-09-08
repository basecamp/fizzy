module StaffOnly
  extend ActiveSupport::Concern

  included do
    before_action :ensure_staff
  end

  private
    def ensure_staff
      head :forbidden unless Current.user.staff?
    end
end
