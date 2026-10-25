require "test_helper"

class Users::ReviewerEmailAddressLockTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @reviewer = identities(:kevin)
    @user = users(:kevin)
    configure email_address: @reviewer.email_address, code_digest: Identity::ReviewerSignIn.digest(Identity::ReviewerSignIn.generate_code)
    sign_in_as :kevin
  end

  teardown { configure email_address: nil, code_digest: nil }

  test "the reviewer can't request an email change" do
    assert_no_enqueued_emails do
      post user_email_addresses_path(@user, script_name: @user.account.slug), params: { email_address: "attacker@example.com" }
    end

    assert_redirected_to edit_user_path(@user, script_name: @user.account.slug)

    post user_email_addresses_path(@user, script_name: @user.account.slug), params: { email_address: "attacker@example.com" }, as: :json
    assert_response :forbidden
  end

  test "a confirmation link minted for the reviewer doesn't move it" do
    token = @user.send(:generate_email_address_change_token, to: "attacker@example.com")

    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: token, script_name: @user.account.slug), as: :json

    assert_response :unprocessable_entity
    assert_equal @reviewer, @user.reload.identity
  end

  private
    def configure(email_address:, code_digest:)
      Rails.application.config.x.reviewer_sign_in.email_address = email_address
      Rails.application.config.x.reviewer_sign_in.code_digest = code_digest
    end
end
