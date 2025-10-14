require "test_helper"

class IdentityMembershipTest < ActionDispatch::IntegrationTest
  setup do
    @tenants = [ ActiveRecord::FixtureSet.identify("identity-tenant-1"),
                 ActiveRecord::FixtureSet.identify("identity-tenant-2") ]
    @tenant_paths = @tenants.map { "/#{_1}" }
    @tenant_urls = @tenant_paths.map { root_url(script_name: _1) }
    @user_params = { email_address: "user@example.com", password: "password1234" }
    @users = @tenants.map do |tenant|
      ApplicationRecord.create_tenant(tenant) do
        Account.create! name: "Account for #{tenant}"
        User.create! @user_params.merge(name: "Harold Hancox")
      end
    end
  end

  test "multiple signins on the same browser" do
    post session_path(script_name: @tenant_paths[0], params: @user_params)
    assert_redirected_to root_path(script_name: @tenant_paths[0])

    post session_path(script_name: @tenant_paths[1], params: @user_params)
    assert_redirected_to root_path(script_name: @tenant_paths[1])

    # Render links for other Fizzies in the jump menu
    get my_menu_path(script_name: @tenant_paths[0])
    assert_select "#my_menu ul li a[href='#{@tenant_urls[1]}']", "Account for #{@tenants[1]}"

    get my_menu_path(script_name: @tenant_paths[1])
    assert_select "#my_menu ul li a[href='#{@tenant_urls[0]}']", "Account for #{@tenants[0]}"

    # Render links for all the identity's Fizzies
    get root_path(script_name: nil)
    assert_select "ul li a[href='#{@tenant_urls[0]}']", "Account for #{@tenants[0]}"
    assert_select "ul li a[href='#{@tenant_urls[1]}']", "Account for #{@tenants[1]}"
  end
end
