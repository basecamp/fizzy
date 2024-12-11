require "test_helper"

class FirstRunsControllerTest < ActionDispatch::IntegrationTest
  #
  # I can't figure out to bootstrap a new tenant database in a transactional test, so this block can
  # all be removed if we figure that out
  #
  self.use_transactional_tests = false

  setup do
    Tenant.destroy_all
  end

  teardown do
    Tenant.destroy_all
  end
  # end of transactional workaround block

  setup do
    integration_session.host = "example.com"
  end

  test "show" do
    get first_run_url

    assert_response :ok
    assert_select "title", text: "Set up Fizzy"
  end

  test "show when requested through a tenant subdomain" do
    Tenant.create! slug: "adequate-co"
    integration_session.host = "adequate-co.example.com"

    get first_run_url
    assert_redirected_to root_url
  end

  test "create" do
    post first_run_url, params: {
           user: { name: "New", email_address: "new@37signals.com", password: "secret123456" },
           tenant: { slug: "adequate-co" }
         }

    assert_redirected_to "http://adequate-co.example.com#{root_path}"

    follow_redirect!

    assert_redirected_to "http://adequate-co.example.com#{new_session_path}"

    follow_redirect!
    assert_response :ok
  end
end
