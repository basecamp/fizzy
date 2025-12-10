require "test_helper"

class Identity::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index lists passkeys for current identity" do
    untenanted do
      get identity_passkeys_url
    end

    assert_response :success
    assert_select "li", text: /iPhone/
  end

  test "index shows empty state when no passkeys" do
    # Use an identity without passkeys
    logout_and_sign_in_as :jz

    untenanted do
      get identity_passkeys_url
    end

    assert_response :success
    assert_match /No passkeys yet/, response.body
  end

  test "new shows passkey registration form" do
    untenanted do
      get new_identity_passkey_url
    end

    assert_response :success
    assert_select "button[data-action*='passkey#register']"
  end

  test "new sets webauthn challenge in session" do
    untenanted do
      get new_identity_passkey_url
    end

    assert_response :success
    assert session[:webauthn_challenge].present?
  end

  test "create with invalid credential redirects with error" do
    untenanted do
      get new_identity_passkey_url

      post identity_passkeys_url, params: { credential: '{"id": "invalid"}' }

      assert_redirected_to new_identity_passkey_url(script_name: nil)
      assert_equal "Could not register passkey.", flash[:alert]
    end
  end

  test "destroy removes passkey" do
    passkey = passkeys(:kevin_iphone)

    untenanted do
      assert_difference -> { Passkey.count }, -1 do
        delete identity_passkey_url(passkey)
      end

      assert_redirected_to identity_passkeys_url(script_name: nil)
      assert_equal "Passkey removed.", flash[:notice]
    end

    assert_not Passkey.exists?(passkey.id)
  end

  test "destroy only allows removing own passkeys" do
    # Kevin is signed in, trying to delete David's passkey
    passkey = passkeys(:david_macbook)

    untenanted do
      delete identity_passkey_url(passkey)
      # Should redirect but not find the passkey (returns 404 or similar behavior)
      # Since find is scoped to Current.identity.passkeys, it won't find david's passkey
      assert_response :not_found
    end
  end

  test "requires authentication" do
    sign_out

    untenanted do
      get identity_passkeys_url
    end

    assert_response :redirect
  end
end
