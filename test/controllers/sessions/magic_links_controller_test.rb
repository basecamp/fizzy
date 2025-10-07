require "test_helper"

class Sessions::MagicLinksControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    get session_magic_link_path

    assert_response :success
  end

  test "create" do
    magic_link = MagicLink.create!(membership: memberships(:kevin_in_37signals))

    post session_magic_link_path, params: { code: magic_link.code }

    assert_redirected_to root_path
    assert cookies[:session_token].present?
    assert_not MagicLink.exists?(magic_link.id)

    post session_magic_link_path, params: { code: "INVALID" }

    assert_redirected_to session_magic_link_path
  end
end
