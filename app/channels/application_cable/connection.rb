module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    tenanted_connection do
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        if session = find_session_by_cookie
          self.current_user = session.user
        end
      end

      def find_session_by_cookie
        Session.find_signed(cookies.signed[:session_token])
      end
  end
end
