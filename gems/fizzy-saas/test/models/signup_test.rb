require "test_helper"

class SignupTest < ActiveSupport::TestCase
  setup do
    @starting_tenants = ApplicationRecord.tenants
    @signup = Signup.new(
      email_address: "brian@example.com",
      full_name: "Brian Wilson",
      company_name: "Beach Boys",
      password: SecureRandom.hex(16)
    )
  end

  test "#process creates all the necessary objects for a new Fizzy account" do
    Account.any_instance.expects(:setup_basic_template).once

    assert @signup.process, @signup.errors.full_messages.to_sentence(words_connector: ". ")
    assert_empty @signup.errors

    assert @signup.tenant
    assert_includes ApplicationRecord.tenants, @signup.tenant

    assert @signup.account
    assert @signup.account.persisted?
    assert @signup.account.external_account_id
    assert_equal @signup.company_name, @signup.account.name
    assert_equal @signup.tenant, @signup.account.external_account_id.to_s
    assert_equal @signup.tenant, @signup.account.tenant

    assert @signup.user
    assert @signup.user.persisted?
    assert_equal @signup.full_name, @signup.user.name
    assert_equal @signup.email_address, @signup.user.email_address

    auth_params = { email_address: @signup.email_address, password: @signup.password }
    user = ApplicationRecord.with_tenant(@signup.tenant) { User.authenticate_by(**auth_params) }

    assert user, "User should be able to authenticate with #{auth_params.inspect}"
    assert_equal @signup.user, user
    assert_equal @signup.tenant, @signup.user.tenant
  end

  test "#process does nothing if a basic validation error occurs" do
    @signup.password = ""

    assert_not @signup.process
    assert_not_empty @signup.errors[:password]

    assert_nil @signup.tenant
    assert_nil @signup.account
    assert_nil @signup.user
    assert_equal @starting_tenants, ApplicationRecord.tenants
  end

  test "#process does nothing if an error occurs creating the queenbee record" do
    Queenbee::Remote::Account.stubs(:create!).raises(RuntimeError, "Invalid account data")

    assert_not @signup.process
    assert_not_empty @signup.errors[:base]

    assert_nil @signup.tenant
    assert_nil @signup.account
    assert_nil @signup.user
    assert_equal @starting_tenants, ApplicationRecord.tenants
  end

  test "#process does nothing if an error occurs creating the tenant" do
    ApplicationRecord.stubs(:create_tenant).raises(RuntimeError, "Tenant already exists")

    Queenbee::Remote::Account.any_instance.expects(:cancel).once

    assert_not @signup.process
    assert_not_empty @signup.errors[:base]

    assert_nil @signup.tenant
    assert_nil @signup.account
    assert_nil @signup.user
    assert_equal @starting_tenants, ApplicationRecord.tenants
  end

  test "#process does nothing if an error occurs creating the tenanted records" do
    Account.stubs(:create_with_admin_user).raises(ActiveRecord::RecordInvalid, "Validation failed: Name can't be blank")

    Queenbee::Remote::Account.any_instance.expects(:cancel).once

    assert_not @signup.process
    assert_not_empty @signup.errors[:base]

    assert_nil @signup.tenant
    assert_nil @signup.account
    assert_nil @signup.user
    assert_equal @starting_tenants, ApplicationRecord.tenants
  end
end
