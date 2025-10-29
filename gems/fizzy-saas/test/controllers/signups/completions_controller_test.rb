require "test_helper"

class Signups::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = Identity.create!(email_address: "newuser@example.com")
    magic_link = @identity.send_magic_link

    untenanted do
      post session_magic_link_url, params: { code: magic_link.code }
      assert_response :redirect, "Magic link should succeed"

      cookie = cookies.get_cookie "session_token"
      assert_not_nil cookie, "Expected session_token cookie to be set after magic link consumption"
    end

    # Create membership first (new step in the flow)
    untenanted do
      post saas.signup_membership_path, params: {
        signup: {
          full_name: "New User",
          company_name: "New Company"
        }
      }, headers: http_basic_auth_headers

      # Extract membership_id from redirect params
      redirect_url = response.location
      @membership_id = Rack::Utils.parse_query(URI.parse(redirect_url).query)["signup[membership_id]"]
    end
  end

  test "new" do
    untenanted do
      get saas.new_signup_completion_path(signup: { membership_id: @membership_id, full_name: "New User", company_name: "New Company" }), headers: http_basic_auth_headers

      assert_response :success
    end
  end

  test "create" do
    untenanted do
      post saas.signup_completion_path, params: {
        signup: {
          membership_id: @membership_id,
          full_name: "New User",
          company_name: "New Company"
        }
      }, headers: http_basic_auth_headers

      tenant = Membership.last.tenant
      assert_redirected_to root_url(script_name: "/#{tenant}"), "Successful completion should redirect to root in new tenant"

      # Test validation error
      post saas.signup_completion_path, params: {
        signup: {
          membership_id: @membership_id,
          full_name: "",
          company_name: ""
        }
      }, headers: http_basic_auth_headers

      assert_response :unprocessable_entity, "Invalid params should return unprocessable entity"
    end
  end

  private
    def http_basic_auth_headers
      { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("testname", "testpassword") }
    end
end
