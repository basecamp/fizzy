require "test_helper"

class User::NotifiesAccountOfEmailChangeTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:"37s")
    @owner = @account.users.find_by(role: :owner) || @account.users.first.tap { |u| u.update!(role: :owner) }
    @member = @account.users.where.not(id: @owner.id).first || @account.users.create!(
      name: "Member",
      identity: Identity.create!(email_address: "member@example.com"),
      role: :member
    )
  end

  test "notifies account when owner changes email" do
    @account.expects(:owner_email_changed).once

    new_identity = Identity.create!(email_address: "new-owner@example.com")
    @owner.update!(identity: new_identity)
  end

  test "does not notify account when non-owner changes email" do
    @account.expects(:owner_email_changed).never

    new_identity = Identity.create!(email_address: "new-member@example.com")
    @member.update!(identity: new_identity)
  end

  test "does not notify account when owner is deactivated" do
    @account.expects(:owner_email_changed).never

    @owner.update!(identity: nil)
  end

  test "does not notify account when identity unchanged" do
    @account.expects(:owner_email_changed).never

    @owner.update!(name: "New Name")
  end

  test "notifies account when user becomes owner" do
    @account.expects(:owner_email_changed).once

    @member.update!(role: :owner)
  end

  test "does not notify account when owner becomes member" do
    @account.expects(:owner_email_changed).never

    @owner.update!(role: :member)
  end
end
