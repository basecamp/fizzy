require "test_helper"

class Account::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :jason
  end

  test "create creates an export record and enqueues job" do
    assert_difference -> { Account::Export.count }, 1 do
      assert_enqueued_with(job: DataExportJob) do
        post account_exports_path
      end
    end

    assert_redirected_to account_settings_path
    assert_equal "Export started. You'll receive an email when it's ready.", flash[:notice]
  end

  test "create associates export with current user" do
    post account_exports_path

    export = Account::Export.last
    assert_equal users(:jason), export.user
    assert_equal Current.account, export.account
    assert export.pending?
  end

  test "create rejects request when current export limit is reached" do
    Account::ExportsController::CURRENT_EXPORT_LIMIT.times do
      Account::Export.create!(account: Current.account, user: users(:jason))
    end

    assert_no_difference -> { Account::Export.count } do
      post account_exports_path
    end

    assert_response :too_many_requests
  end

  test "create allows request when exports are older than one day" do
    Account::ExportsController::CURRENT_EXPORT_LIMIT.times do
      Account::Export.create!(account: Current.account, user: users(:jason), created_at: 2.days.ago)
    end

    assert_difference -> { Account::Export.count }, 1 do
      post account_exports_path
    end

    assert_redirected_to account_settings_path
  end

  test "show displays completed export with download link" do
    export = Account::Export.create!(account: Current.account, user: users(:jason))
    export.build

    get account_export_path(export)

    assert_response :success
    assert_select "a#download-link"
  end

  test "show displays a warning if the export is missing" do
    get account_export_path("not-really-an-export")

    assert_response :success
    assert_select "h2", "Download Expired"
  end

  test "show does not allow access to another user's export" do
    export = Account::Export.create!(account: Current.account, user: users(:kevin))
    export.build

    get account_export_path(export)

    assert_response :success
    assert_select "h2", "Download Expired"
  end

  test "create as JSON" do
    assert_difference -> { Account::Export.count }, 1 do
      assert_enqueued_with(job: DataExportJob) do
        post account_exports_path, as: :json
      end
    end

    assert_response :created
    body = @response.parsed_body
    assert body["id"].present?
    assert_equal "pending", body["status"]
    assert_nil body["download_url"]
  end

  test "show as JSON with completed export" do
    export = Account::Export.create!(account: Current.account, user: users(:jason))
    export.build

    get account_export_path(export), as: :json
    assert_response :success

    body = @response.parsed_body
    assert_equal export.id, body["id"]
    assert_equal "completed", body["status"]
    assert body["download_url"].present?
  end

  test "show as JSON with bearer token returns a download URL that can be fetched" do
    export = Account::Export.create!(account: Current.account, user: users(:jason))
    export.build
    sign_out
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:jasons_api_token).token}" }

    get account_export_path(export), as: :json, env: bearer_token
    assert_response :success

    body = @response.parsed_body
    assert_equal export.id, body["id"]
    assert_equal "completed", body["status"]
    assert body["download_url"].present?

    get URI(body["download_url"]).request_uri, env: bearer_token
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "show as JSON with pending export" do
    export = Account::Export.create!(account: Current.account, user: users(:jason))

    get account_export_path(export), as: :json
    assert_response :success

    body = @response.parsed_body
    assert_equal "pending", body["status"]
    assert_nil body["download_url"]
  end

  test "show as JSON with missing export" do
    get account_export_path("nonexistent"), as: :json
    assert_response :not_found
  end

  test "create is forbidden for non-admin members" do
    logout_and_sign_in_as :david

    post account_exports_path

    assert_response :forbidden
  end

  test "show is forbidden for non-admin members" do
    logout_and_sign_in_as :david
    export = Account::Export.create!(account: Current.account, user: users(:jason))
    export.build

    get account_export_path(export)

    assert_response :forbidden
  end
end
