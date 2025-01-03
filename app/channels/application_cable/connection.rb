module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_tenant

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        self.current_tenant = ActiveRecord::Tenanted::Tenant.requested_tenant(request)
        ActiveRecord::Tenanted::Tenant.while_tenanted(current_tenant) do
          if session = find_session_by_cookie
            self.current_user = session.user
          end
        end
      end

      def find_session_by_cookie
        Session.find_signed(cookies.signed[:session_token])
      end
  end
end
