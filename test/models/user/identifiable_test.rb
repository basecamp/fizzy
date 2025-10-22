require "test_helper"

class User::IdentifiableTest < ActiveSupport::TestCase
  test "create" do
    user = User.create!(
      role: "member",
      name: "New User",
      email_address: "newuser@example.com"
    )

    assert user.identity.present?
    assert_equal "newuser@example.com", user.identity.email_address
  end

  test "destroy" do
    user = User.create!(name: "Bob")

    assert Identity.find_by(email_address: user.email_address)

    user.destroy!

    assert_not Identity.find_by(email_address: user.email_address).memberships.exists?(tenant: user.tenant)
  end
end
