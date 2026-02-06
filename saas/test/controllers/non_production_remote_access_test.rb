require "test_helper"

class NonProductionRemoteAccessTest < ActionDispatch::IntegrationTest
  test "employee can access in staging environment" do
    assert_predicate identities(:david), :employee?

    sign_in_as :david

    Rails.stubs(:env).returns(ActiveSupport::EnvironmentInquirer.new("staging"))
    get cards_path
    assert_response :success
  end

  test "non-employee cannot access in staging environment" do
    identities(:jz).update!(email_address: "david@example.com")
    assert_not_predicate identities(:jz), :employee?

    sign_in_as :jz

    Rails.stubs(:env).returns(ActiveSupport::EnvironmentInquirer.new("staging"))
    get cards_path
    assert_response :forbidden
  end

  test "non-employee can access in production environment" do
    identities(:jz).update!(email_address: "david@example.com")
    assert_not_predicate identities(:jz), :employee?

    sign_in_as :jz

    Rails.stubs(:env).returns(ActiveSupport::EnvironmentInquirer.new("production"))
    get cards_path
    assert_response :success
  end

  test "non-employee can access in beta environment" do
    identities(:jz).update!(email_address: "david@example.com")
    assert_not_predicate identities(:jz), :employee?

    sign_in_as :jz

    Rails.stubs(:env).returns(ActiveSupport::EnvironmentInquirer.new("beta"))
    get cards_path
    assert_response :success
  end

  test "non-employee can access in local environment" do
    identities(:jz).update!(email_address: "david@example.com")
    assert_not_predicate identities(:jz), :employee?

    sign_in_as :jz

    get cards_path
    assert_response :success
  end
end
