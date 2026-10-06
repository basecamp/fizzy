require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    setup do
      # Use non-37s account to assess that Current.account is set correctly
      @account = accounts(:initech)
      @session = sessions(:mike)
    end

    test "connects with valid session and account info" do
      cookies.signed[:session_token] = @session.signed_id

      connect "/cable", env: { "fizzy.external_account_id" => @account.external_account_id }

      assert_equal users(:mike), connection.current_user
      assert_equal @account, Current.account
    end

    test "rejects a session without single sign-on when single sign-on is configured" do
      cookies.signed[:session_token] = @session.signed_id

      with_single_sign_on do
        assert_reject_connection do
          connect "/cable", env: { "fizzy.external_account_id" => @account.external_account_id }
        end
      end
    end

    test "connects a recent single sign-on session when single sign-on is configured" do
      cookies.signed[:session_token] = @session.signed_id
      @session.update!(single_sign_on_authenticated_at: Time.current)

      with_single_sign_on do
        connect "/cable", env: { "fizzy.external_account_id" => @account.external_account_id }
      end

      assert_equal users(:mike), connection.current_user
    end

    test "rejects a recent single sign-on session outside the account group" do
      cookies.signed[:session_token] = @session.signed_id
      @session.update!(single_sign_on_authenticated_at: Time.current, single_sign_on_groups: [ "/sales" ])

      with_single_sign_on do
        @account.update!(single_sign_on_group: "/engineering/fizzy")

        assert_reject_connection do
          connect "/cable", env: { "fizzy.external_account_id" => @account.external_account_id }
        end
      end
    end

    test "rejects with invalid session token" do
      cookies.signed[:session_token] = "invalid-session-id"

      assert_reject_connection do
        connect "/cable", env: { "fizzy.external_account_id" => @account.external_account_id }
      end
    end

    test "rejects when account does not exist" do
      cookies.signed[:session_token] = @session.signed_id

      assert_reject_connection do
        connect "/cable", env: { "fizzy.external_account_id" => -1 }
      end
    end
  end
end
