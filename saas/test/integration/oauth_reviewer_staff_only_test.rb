require "test_helper"

# Directory reviewers (Identity::ReviewerSignIn) connect apps while OAuth is
# staff only, without being staff; everyone else is still refused.
class OauthReviewerStaffOnlyTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

  CODE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

  setup do
    @reviewer = identities(:mike)
    assert_not @reviewer.staff?, "the reviewer under test must not be staff"
    configure code_digests: "#{@reviewer.email_address}=#{Identity::ReviewerSignIn.digest(Identity::ReviewerSignIn.generate_code)}"
  end

  teardown { configure code_digests: nil }

  test "the staff gate admits a reviewer, staff, and no one else" do
    with_oauth_availability staff_only: true do
      assert Oauth::Availability.admits?(@reviewer)
      assert Oauth::Availability.admits?(identities(:david))
      assert_not Oauth::Availability.admits?(identities(:jz))
      assert_not Oauth::Availability.admits?(nil)
    end
  end

  test "a reviewer stays out of admin" do
    with_oauth_availability staff_only: true do
      sign_in_as @reviewer
      untenanted { get saas.admin_stats_path }
    end

    assert_response :forbidden
  end

  test "a reviewer whose code is turned off still passes, and one taken off the list doesn't" do
    with_oauth_availability staff_only: true do
      configure code_digests: "#{@reviewer.email_address}="
      assert Oauth::Availability.admits?(@reviewer)

      configure code_digests: nil
      assert_not Oauth::Availability.admits?(@reviewer)
    end
  end

  test "a reviewer sees the consent screen and connects" do
    with_oauth_availability staff_only: true do
      sign_in_as @reviewer
      get_consent_screen
      assert_response :success

      post_consent
      assert_response :redirect
      assert_match %r{\Ahttp://127\.0\.0\.1:8888/callback\?code=}, response.location
    end
  end

  test "anyone else is still told OAuth is staff only" do
    with_oauth_availability staff_only: true do
      sign_in_as :jz
      get_consent_screen
      assert_response :forbidden
    end
  end

  test "a reviewer's grant works and refreshes, and stops once they're off the list" do
    grant = @reviewer.access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    with_oauth_availability staff_only: true do
      get user_path(users(:mike)), env: { "HTTP_AUTHORIZATION" => "Bearer #{grant.raw_token}" }, as: :json
      assert_response :success

      refresh grant
      assert_response :success
      grant = Identity::AccessToken.find_by_raw_token(response.parsed_body["access_token"])

      configure code_digests: nil
      get user_path(users(:mike)), env: { "HTTP_AUTHORIZATION" => "Bearer #{grant.raw_token}" }, as: :json
      assert_response :unauthorized
    end
  end

  test "a non-reviewer's grant is still refused" do
    grant = identities(:jz).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    with_oauth_availability staff_only: true do
      get user_path(users(:jz)), env: { "HTTP_AUTHORIZATION" => "Bearer #{grant.raw_token}" }, as: :json
    end

    assert_response :unauthorized
  end

  private
    def configure(code_digests:)
      Rails.application.config.x.reviewer_sign_in.code_digests = code_digests
    end

    def get_consent_screen
      untenanted { get new_oauth_authorization_path, params: consent_params }
    end

    def post_consent
      untenanted { post oauth_authorization_path, params: consent_params }
    end

    def consent_params
      {
        client_id: oauth_clients(:mcp_client).client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(CODE_VERIFIER), padding: false),
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }
    end

    def refresh(grant)
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: grant.raw_refresh_token, client_id: oauth_clients(:mcp_client).client_id }, as: :json
      end
    end
end
