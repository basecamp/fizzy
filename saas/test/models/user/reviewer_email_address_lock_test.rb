require "test_helper"

class User::ReviewerEmailAddressLockTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @code = Identity::ReviewerSignIn.generate_code
    @reviewer = identities(:kevin)
    @user = users(:kevin)
    configure email_address: @reviewer.email_address, code_digest: Identity::ReviewerSignIn.digest(@code)
  end

  teardown { configure email_address: nil, code_digest: nil }

  test "the reviewer can't move its user to an address a code holder controls, so sign-out still reaches it" do
    token = @user.send(:generate_email_address_change_token, to: "attacker@example.com")
    @reviewer.sessions.create!

    assert_not @user.change_email_address_using_token(token)
    assert_equal @reviewer, @user.reload.identity
    assert_nil Identity.find_by(email_address: "attacker@example.com")

    assert_operator Identity::ReviewerSignIn.sign_out_everywhere, :>, 0
    assert_empty @reviewer.sessions.reload
    assert_nil Identity::ReviewerSignIn.authenticate(email_address: "attacker@example.com", code: @code)
  end

  test "the reviewer gets no email change confirmation" do
    assert_no_enqueued_emails do
      @user.send_email_address_change_confirmation("attacker@example.com")
    end
  end

  test "everyone else can still change their email address" do
    user = users(:david)

    assert user.change_email_address("david.new@example.com")
    assert_equal "david.new@example.com", user.reload.identity.email_address
  end

  test "nobody is locked when the reviewer isn't configured" do
    configure email_address: nil, code_digest: nil

    assert_not @user.email_address_locked?
  end

  private
    def configure(email_address:, code_digest:)
      Rails.application.config.x.reviewer_sign_in.email_address = email_address
      Rails.application.config.x.reviewer_sign_in.code_digest = code_digest
    end
end
