require "test_helper"

class Sessions::MagicLinksControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    untenanted do
      get session_magic_link_url

      assert_response :success
    end
  end

  test "create" do
    untenanted do
      identity = identities(:kevin)
      magic_link = MagicLink.create!(identity: identity)

      post session_magic_link_url, params: { code: magic_link.code }

      assert_response :redirect, "Valid magic link should redirect"
      assert cookies[:identity_token].present?, "Valid magic link should set identity token"
      assert_not MagicLink.exists?(magic_link.id), "Valid magic link should be consumed"

      post session_magic_link_url, params: { code: "INVALID" }

      assert_response :redirect, "Invalid code should redirect"

      expired_link = MagicLink.create!(identity: identity)
      expired_link.update_column(:expires_at, 1.hour.ago)

      post session_magic_link_url, params: { code: expired_link.code }

      assert_response :redirect, "Expired magic link should redirect"
      assert MagicLink.exists?(expired_link.id), "Expired magic link should not be consumed"
    end
  end
end
