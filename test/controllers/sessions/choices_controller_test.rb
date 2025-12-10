require "test_helper"

class Sessions::ChoicesControllerTest < ActionDispatch::IntegrationTest
  test "new shows choice page for user with passkeys" do
    identity = identities(:kevin) # has passkeys

    untenanted do
      get new_session_choice_path(email: identity.email_address)
    end

    assert_response :success
    assert_select "button[data-action*='passkey#authenticate']"
    assert_match /Use passkey/, response.body
    assert_match /Send me a magic link/, response.body
  end

  test "new redirects to session page if no passkeys" do
    identity = identities(:jz) # no passkeys

    untenanted do
      get new_session_choice_path(email: identity.email_address)

      assert_redirected_to new_session_url(script_name: nil)
    end
  end

  test "new redirects to session page if identity not found" do
    untenanted do
      get new_session_choice_path(email: "nonexistent@example.com")

      assert_redirected_to new_session_url(script_name: nil)
    end
  end

  test "new sets webauthn challenge in session" do
    identity = identities(:kevin)

    untenanted do
      get new_session_choice_path(email: identity.email_address)
    end

    assert_response :success
    assert session[:webauthn_challenge].present?
  end

  test "create with magic_link method sends magic link" do
    identity = identities(:kevin)

    untenanted do
      get new_session_choice_path(email: identity.email_address)

      assert_difference -> { MagicLink.count }, 1 do
        post session_choice_path, params: { email: identity.email_address, method: "magic_link" }
      end

      assert_redirected_to session_magic_link_path
    end
  end

  test "create with invalid passkey credential shows error" do
    identity = identities(:kevin)

    untenanted do
      get new_session_choice_path(email: identity.email_address)

      post session_choice_path, params: {
        email: identity.email_address,
        method: "passkey",
        credential: '{"id": "invalid"}'
      }

      assert_redirected_to new_session_choice_path(email: identity.email_address)
      assert_equal "Authentication failed. Try again.", flash[:alert]
    end
  end
end
