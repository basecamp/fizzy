require "test_helper"

class Users::DataExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    @user = users(:david)
  end

  test "create creates an export record and enqueues job" do
    assert_difference -> { User::DataExport.count }, 1 do
      assert_enqueued_with(job: DataExportJob) do
        post user_data_exports_path(@user)
      end
    end

    assert_redirected_to @user
    assert_equal "Export started. You'll receive an email when it's ready.", flash[:notice]
  end

  test "create associates export with user and account" do
    post user_data_exports_path(@user)

    export = User::DataExport.last
    assert_equal @user, export.user
    assert_equal Current.account, export.account
    assert export.pending?
  end

  test "create rejects request when current export limit is reached" do
    Users::DataExportsController::CURRENT_EXPORT_LIMIT.times do
      @user.data_exports.create!(account: Current.account)
    end

    assert_no_difference -> { User::DataExport.count } do
      post user_data_exports_path(@user)
    end

    assert_response :too_many_requests
  end

  test "create allows request when exports are older than one day" do
    Users::DataExportsController::CURRENT_EXPORT_LIMIT.times do
      @user.data_exports.create!(account: Current.account, created_at: 2.days.ago)
    end

    assert_difference -> { User::DataExport.count }, 1 do
      post user_data_exports_path(@user)
    end

    assert_redirected_to @user
  end

  test "show displays completed export with download link" do
    export = @user.data_exports.create!(account: Current.account)
    export.build

    get user_data_export_path(@user, export)

    assert_response :success
    assert_select "a#download-link"
  end

  test "show displays a warning if the export is missing" do
    get user_data_export_path(@user, "not-really-an-export")

    assert_response :success
    assert_select "h2", "Download Expired"
  end

  test "create is forbidden for other users" do
    other_user = users(:kevin)

    post user_data_exports_path(other_user)

    assert_response :forbidden
  end

  test "show is forbidden for other users" do
    other_user = users(:kevin)
    export = other_user.data_exports.create!(account: Current.account)
    export.build

    get user_data_export_path(other_user, export)

    assert_response :forbidden
  end
end
