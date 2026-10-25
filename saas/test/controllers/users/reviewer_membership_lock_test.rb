require "test_helper"

class Users::ReviewerMembershipLockTest < ActionDispatch::IntegrationTest
  setup do
    @reviewer = identities(:kevin)
    @user = users(:kevin)
    configure email_address: @reviewer.email_address, code_digest: Identity::ReviewerSignIn.digest(Identity::ReviewerSignIn.generate_code)
  end

  teardown { configure email_address: nil, code_digest: nil }

  test "the reviewer can't deactivate itself" do
    sign_in_as :kevin

    delete user_path(@user, script_name: @user.account.slug), as: :json

    assert_response :forbidden
    assert @user.reload.active?
    assert_equal @reviewer, @user.identity
    assert_includes @reviewer.accounts.reload, @user.account
  end

  test "another admin can't deactivate the reviewer either" do
    admin = @user.account.users.where.not(id: @user.id).find { |user| user.identity && user.can_change?(@user) } || \
      flunk("fixture needs another admin in the reviewer's account")
    sign_in_as admin.identity

    delete user_path(@user, script_name: @user.account.slug)

    assert_redirected_to account_settings_path(script_name: @user.account.slug)
    assert @user.reload.active?
  end

  test "other users can still be deactivated" do
    configure email_address: identities(:jason).email_address, code_digest: nil
    sign_in_as :kevin
    other = @user.account.users.where.not(id: @user.id).find { |user| user.identity && @user.can_change?(user) && !user.owner? } || \
      flunk("fixture needs a user kevin can change")

    delete user_path(other, script_name: other.account.slug), as: :json

    assert_response :no_content
    assert_not other.reload.active?
  end

  private
    def configure(email_address:, code_digest:)
      Rails.application.config.x.reviewer_sign_in.email_address = email_address
      Rails.application.config.x.reviewer_sign_in.code_digest = code_digest
    end
end
