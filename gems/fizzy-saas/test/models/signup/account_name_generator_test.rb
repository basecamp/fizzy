require "test_helper"

class Signup::AccountNameGeneratorTest < ActiveSupport::TestCase
  setup do
    @identity = Identity.create!(email_address: "newart.userbaum@example.com")
    @name = "Newart userbaum"
    @generator = Signup::AccountNameGenerator.new(identity: @identity, name: @name)
  end

  test "generate" do
    account_name = @generator.generate
    assert_equal "Newart's Fizzy", account_name, "The 1st account doesn't have 1st in the name"

    first_membership = @identity.memberships.create(tenant: "1st")
    first_membership.stubs(:account_name).returns(account_name)

    account_name = @generator.generate
    assert_equal "Newart's 2nd Fizzy", account_name

    second_membership = @identity.memberships.create(tenant: "2nd")
    second_membership.stubs(:account_name).returns(account_name)

    account_name = @generator.generate
    assert_equal "Newart's 3rd Fizzy", account_name

    third_membership = @identity.memberships.create(tenant: "3nd")
    third_membership.stubs(:account_name).returns(account_name)

    account_name = @generator.generate
    assert_equal "Newart's 4th Fizzy", account_name

    fourth_membership = @identity.memberships.create(tenant: "4th")
    fourth_membership.stubs(:account_name).returns(account_name)

    account_name = @generator.generate
    assert_equal "Newart's 5th Fizzy", account_name
  end

  test "generate continues from the previous highest index" do
    membership = @identity.memberships.create(tenant: "12th")
    membership.stubs(:account_name).returns("Newart's 12th Fizzy")

    account_name = @generator.generate
    assert_equal "Newart's 13th Fizzy", account_name
  end
end
