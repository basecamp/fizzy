require "test_helper"

class My::IdentitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show as JSON" do
    identity = identities(:kevin)

    untenanted do
      get my_identity_path, as: :json
      assert_response :success
      assert_equal identity.accounts.count, @response.parsed_body["accounts"].count
    end
  end
end
