module SessionTestHelper
  def parsed_cookies
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
  end

  def sign_in_as(user)
    cookies.delete :session_token
    user = users(user) unless user.is_a? User

    set_identity_as user

    user.reload
    membership = user.membership
    tenanted do
      post session_login_menu_url, params: { membership_id: membership.id }
      assert_response :redirect, "Login should succeed"

      cookie = cookies.get_cookie "session_token"
      assert_not_nil cookie, "Expected session_token cookie to be set after sign in"
      assert_equal Account.sole.slug, cookie.path, "Expected session_token cookie to be scoped to account slug"
    end
  end

  def set_identity_as(user_or_identity)
    user = if user_or_identity.is_a?(User)
      user_or_identity
    else
      users(user_or_identity)
    end

    membership = user.membership || user.set_identity(nil).memberships.find_by(user_id: user.id, user_tenant: user.tenant)
    membership.send_magic_link

    magic_link = membership.magic_links.order(id: :desc).first

    untenanted do
      post session_magic_link_url, params: { code: magic_link.code }
      assert_response :redirect, "Magic link should succeed"

      cookie = cookies.get_cookie "identity_token"
      assert_not_nil cookie, "Expected identity_token cookie to be set after magic link consumption"
    end
  end

  def sign_out
    delete session_path
    assert_not cookies[:session_token].present?
  end

  def with_current_user(user)
    user = users(user) unless user.is_a? User
    Current.session = Session.new(user: user)
    yield
  ensure
    Current.clear_all
  end

  def untenanted(&block)
    original_script_name = integration_session.default_url_options[:script_name]
    integration_session.default_url_options[:script_name] = ""
    yield
  ensure
    integration_session.default_url_options[:script_name] = original_script_name
  end

  def tenanted(tenant = ApplicationRecord.current_tenant, &block)
    original_script_name = integration_session.default_url_options[:script_name]
    integration_session.default_url_options[:script_name] = "/#{tenant}"
    yield
  ensure
    integration_session.default_url_options[:script_name] = original_script_name
  end
end
