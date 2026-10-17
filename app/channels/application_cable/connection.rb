module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    # Only the handshake checks single sign-on, so the heartbeat closes a connection that outlives its sign-in.
    def beat
      if single_sign_on_expired?
        close reason: ActionCable::INTERNAL[:disconnect_reasons][:unauthorized], reconnect: true
      else
        super
      end
    end

    private
      def set_current_user
        if @session = find_session_by_cookie
          account = Account.find_by(external_account_id: request.env["fizzy.external_account_id"])
          Current.account = account
          self.current_user = @session.identity.users.find_by!(account: account) if account&.accessible_with?(@session)
        end
      end

      def find_session_by_cookie
        Session.find_signed(cookies.signed[:session_token])
      end

      def single_sign_on_expired?
        SingleSignOn.configured? && !@session.recently_authenticated_by_single_sign_on?
      end
  end
end
