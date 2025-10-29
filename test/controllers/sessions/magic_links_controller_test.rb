require "test_helper"

class Sessions::MagicLinksControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    untenanted do
      get session_magic_link_url

      assert_response :success
    end
  end

  test "create" do
    identity = identities(:kevin)
    magic_link = MagicLink.create!(identity: identity)

    untenanted do
      post session_magic_link_url, params: { code: magic_link.code }
    end

    assert_response :redirect
    assert cookies[:session_token].present?
    assert_not MagicLink.exists?(magic_link.id), "The magic link should be consumed"
  end

  test "create with invalid code" do
    identity = identities(:kevin)
    magic_link = MagicLink.create!(identity: identity)

    untenanted do
      post session_magic_link_url, params: { code: "INVALID" }
    end

    assert_response :redirect, "Invalid code should redirect"

    expired_link = MagicLink.create!(identity: identity)
    expired_link.update_column(:expires_at, 1.hour.ago)

    post session_magic_link_url, params: { code: expired_link.code }

    assert_response :redirect, "Expired magic link should redirect"
    assert MagicLink.exists?(expired_link.id), "Expired magic link should not be consumed"
  end
end
