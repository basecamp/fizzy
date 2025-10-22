require "test_helper"

class Signups::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = Identity.create!(email_address: "newuser@example.com")
    magic_link = @identity.send_magic_link

    untenanted do
      post session_magic_link_url, params: { code: magic_link.code }
      assert_response :redirect, "Magic link should succeed"

      cookie = cookies.get_cookie "identity_token"
      assert_not_nil cookie, "Expected identity_token cookie to be set after magic link consumption"
    end
  end

  test "new" do
    untenanted do
      get saas.new_signup_completion_path, headers: http_basic_auth_headers

      assert_response :success
    end
  end

  test "create" do
    untenanted do
      assert_difference -> { Membership.count }, 1 do
        post saas.signup_completion_path, params: {
          signup: {
            full_name: "New User",
            company_name: "New Company"
          }
        }, headers: http_basic_auth_headers
      end

      tenant = Membership.last.tenant
      assert_redirected_to new_session_start_url(script_name: "/#{tenant}"), "Successful completion should redirect to start session in new tenant"

      post saas.signup_completion_path, params: {
        signup: {
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
