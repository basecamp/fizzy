require "test_helper"

class Membership::EmailAddressChangeableTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @identity = identities(:kevin)
    @tenant = ApplicationRecord.current_tenant
    @membership = @identity.memberships.find_by!(tenant: @tenant)
    @new_email = "newart@example.com"
  end

  test "send_email_address_change_confirmation" do
    assert_emails 1 do
      @membership.send_email_address_change_confirmation(@new_email)
    end
  end

  test "change_email_address" do
    old_identity = @identity

    assert_difference -> { Identity.count }, +1 do
      @membership.change_email_address(@new_email)
    end

    assert_equal @new_email, @membership.reload.identity.email_address
    assert_not old_identity.reload.memberships.exists?(id: @membership.id)
    assert_equal @new_email, @membership.reload.identity.email_address

    # Make sure that a prior membership doesn't exist
    identities(:david).memberships.where(tenant: @tenant).delete_all

    assert_no_difference -> { Identity.count } do
      @membership.change_email_address(identities(:david).email_address)
    end
    assert_equal identities(:david).email_address, @membership.reload.identity.email_address
  end

  test "change_email_address_using_token" do
    token = @membership.send(:generate_email_address_change_token, to: @new_email)

    Membership.change_email_address_using_token(token)

    assert_equal @new_email, @membership.reload.identity.email_address
  end

  test "change_email_address_using_token with invalid token" do
    assert_raises(ArgumentError, match: /invalid/) do
      Membership.change_email_address_using_token("invalid_token")
    end

    token = @membership.send(:generate_email_address_change_token, to: @new_email)
    @identity.update!(email_address: "different@example.com")

    assert_raises(ArgumentError, match: /different email address/) do
      Membership.change_email_address_using_token(token)
    end
  end
end
