require "test_helper"

class Signups::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = Identity.create!(email_address: "newuser@example.com")
    magic_link = @identity.send_magic_link

    untenanted do
      post session_magic_link_url, params: { code: magic_link.code }
      assert_response :redirect, "Magic link should succeed"

      cookie = cookies.get_cookie "session_token"
      assert_not_nil cookie, "Expected session_token cookie to be set after magic link consumption"
    end
  end

  test "new" do
    untenanted do
      get saas.new_signup_membership_path, headers: http_basic_auth_headers

      assert_response :success
    end
  end

  test "new with new_user param" do
    untenanted do
      get saas.new_signup_membership_path(signup: { new_user: true }), headers: http_basic_auth_headers

      assert_response :success
    end
  end

  test "create" do
    untenanted do
      assert_difference -> { Membership.count }, 1 do
        post saas.signup_membership_path, params: {
          signup: {
            full_name: "New User",
            company_name: "New Company"
          }
        }, headers: http_basic_auth_headers
      end

      assert_redirected_to saas.new_signup_completion_path(
        signup: {
          membership_id: Membership.last.signed_id(purpose: :account_creation),
          full_name: "New User",
          company_name: "New Company"
        }
      ), "Successful membership creation should redirect to completion step"
    end
  end

  test "create with validation errors" do
    untenanted do
      assert_no_difference -> { Membership.count } do
        post saas.signup_membership_path, params: {
          signup: {
            full_name: "",
            company_name: ""
          }
        }, headers: http_basic_auth_headers
      end

      assert_response :unprocessable_entity, "Invalid params should return unprocessable entity"
    end
  end

  test "create with new_user flag generates personal account name" do
    untenanted do
      post saas.signup_membership_path, params: {
        signup: {
          full_name: "John Smith",
          new_user: true
        }
      }, headers: http_basic_auth_headers

      # When new_user is true and company_name is blank, it should use personal account name
      # Follow the redirect to check the generated company name
      assert_response :redirect
      redirect_params = Rack::Utils.parse_query(URI.parse(response.location).query)
      assert_equal "John's BOXCAR", redirect_params["signup[company_name]"]
    end
  end

  private
    def http_basic_auth_headers
      { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("testname", "testpassword") }
    end
end
