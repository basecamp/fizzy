require "test_helper"

class Sessions::MenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:kevin)
  end

  test "show with no memberships" do
    sign_in_as @identity
    @identity.memberships.delete_all

    untenanted do
      get session_menu_url
    end

    assert_response :success, "Renders an empty menu"
  end

  test "show with exactly one membership" do
    sign_in_as @identity
    @identity.memberships.delete_all
    @identity.memberships.create(tenant: "37signals")

    untenanted do
      get session_menu_url
    end

    assert_response :redirect
    assert_redirected_to root_url(script_name: "/37signals")
  end

  test "show with multiple memeberships" do
    sign_in_as @identity
    @identity.memberships.delete_all
    @identity.memberships.create(tenant: "37signals")
    @identity.memberships.create(tenant: "acme")

    untenanted do
      get session_menu_url
    end

    assert_response :success
  end

  test "show renders as a menu section" do
    sign_in_as @identity
    @identity.memberships.delete_all
    @identity.memberships.create(tenant: "37signals")
    @identity.memberships.create(tenant: "acme")

    untenanted do
      get session_menu_url menu_section: true
    end

    assert_response :success
  end

  test "show doesn't redirect when rendered as a menu section" do
    sign_in_as @identity
    @identity.memberships.delete_all
    @identity.memberships.create(tenant: "37signals")

    untenanted do
      get session_menu_url menu_section: true
    end

    assert_response :success
  end
end
