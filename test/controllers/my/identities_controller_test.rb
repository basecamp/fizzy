require "test_helper"

class My::IdentitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show as JSON" do
    identity = identities(:kevin)
    expected_count = identity.users_with_active_accounts.count

    untenanted do
      get my_identity_path, as: :json
      assert_response :success
      assert_equal identity.id, @response.parsed_body["id"]
      assert_equal expected_count, @response.parsed_body["accounts"].count
    end
  end

  test "show as JSON includes users from active accounts only" do
    identity = identities(:kevin)

    active_account = Account.create!(external_account_id: 9999981, name: "Active Account")
    cancelled_account = Account.create!(external_account_id: 9999982, name: "Cancelled Account")

    identity.users.create!(account: active_account, name: "Kevin", role: :owner)

    cancelling_user = identity.users.create!(account: cancelled_account, name: "Kevin", role: :owner)
    cancelled_account.cancel(initiated_by: cancelling_user)

    untenanted do
      get my_identity_path, as: :json
      assert_response :success

      account_ids = @response.parsed_body["accounts"].map { |account| account["id"] }

      assert_includes account_ids, active_account.id
      assert_not_includes account_ids, cancelled_account.id
    end
  end
end
