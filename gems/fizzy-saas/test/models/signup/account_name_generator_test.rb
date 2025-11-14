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

    first_account = Account.create!(external_account_id: "1st", name: account_name)
    Current.without_account do
      @identity.users.create!(account: first_account, name: @name)
      @identity.reload
    end

    account_name = @generator.generate
    assert_equal "Newart's 2nd Fizzy", account_name

    second_account = Account.create!(external_account_id: "2nd", name: account_name)
    Current.without_account do
      @identity.users.create!(account: second_account, name: @name)
      @identity.reload
    end

    account_name = @generator.generate
    assert_equal "Newart's 3rd Fizzy", account_name

    third_account = Account.create!(external_account_id: "3rd", name: account_name)
    Current.without_account do
      @identity.users.create!(account: third_account, name: @name)
      @identity.reload
    end

    account_name = @generator.generate
    assert_equal "Newart's 4th Fizzy", account_name

    fourth_account = Account.create!(external_account_id: "4th", name: account_name)
    Current.without_account do
      @identity.users.create!(account: fourth_account, name: @name)
      @identity.reload
    end

    account_name = @generator.generate
    assert_equal "Newart's 5th Fizzy", account_name
  end

  test "generate continues from the previous highest index" do
    account = Account.create!(external_account_id: "12th", name: "Newart's 12th Fizzy")
    Current.without_account do
      @identity.users.create!(account: account, name: @name)
      @identity.reload
    end

    account_name = @generator.generate
    assert_equal "Newart's 13th Fizzy", account_name
  end
end
