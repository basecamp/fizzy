require "test_helper"

class FirstRunsControllerTest < ActionDispatch::IntegrationTest
  # Transactional fixtures wrap everything in a transaction, including the temporary migration
  # connection pool we use to instantiate a new tenant database. Until I figure out a solution,
  # let's skip the transactions for this test file.
  self.use_transactional_tests = false

  test "show" do
    integration_session.host = "example.com" # no subdomain

    get first_run_url

    assert_response :ok
    assert_select "title", text: "Set up Fizzy"
  end

  test "show when requested through a tenant subdomain" do
    get first_run_url

    assert_redirected_to root_url
  end

  test "create" do
    integration_session.host = "example.com" # no subdomain
    tenant_name = "first-run-create-test"

    post(first_run_url, params: { user: { name: "New", email_address: "new@37signals.com", password: "secret123456" }, subdomain: tenant_name })

    Tenant.while_tenanted(tenant_name) do
      assert_equal(1, Account.count)
    end

    assert_redirected_to %r{http://#{tenant_name}.example.com/}

    follow_redirect!

    assert_response :ok
  ensure
    Tenant.destroy(tenant_name)
  end

  test "create a duplicate" do
    integration_session.host = "example.com" # no subdomain
    tenant_name = "first-run-create-duplicate-test"
    Tenant.create(tenant_name)

    post(first_run_url, params: { user: { name: "New", email_address: "new@37signals.com", password: "secret123456" }, subdomain: tenant_name })

    assert_response :ok
    assert_select "div#alert", text: 'Subdomain "first-run-create-duplicate-test" is already taken.'
  ensure
    Tenant.destroy(tenant_name)
  end
end
