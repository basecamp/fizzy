require "test_helper"
require "rack/mock"

class AccountSlugExtractorTest < ActiveSupport::TestCase
  test "moves account prefix from PATH_INFO to SCRIPT_NAME" do
    account = accounts(:initech)
    slug = AccountSlug.encode(account.external_account_id)

    captured = call_with_env "/#{slug}/boards"

    assert_equal "/#{slug}", captured.fetch(:script_name)
    assert_equal "/boards", captured.fetch(:path_info)
    assert_equal account.external_account_id, captured.fetch(:external_account_id)
    assert_equal account, captured.fetch(:current_account)
  end

  test "treats a bare account prefix as the root path" do
    account = accounts(:initech)
    slug = AccountSlug.encode(account.external_account_id)

    captured = call_with_env "/#{slug}"

    assert_equal "/#{slug}", captured.fetch(:script_name)
    assert_equal "/", captured.fetch(:path_info)
  end

  test "detects the account prefix when already in SCRIPT_NAME" do
    account = accounts(:initech)
    slug = AccountSlug.encode(account.external_account_id)

    captured = call_with_env "/boards", "SCRIPT_NAME" => "/#{slug}"

    assert_equal "/#{slug}", captured.fetch(:script_name)
    assert_equal "/boards", captured.fetch(:path_info)
    assert_equal account, captured.fetch(:current_account)
  end

  test "clears Current.account when no account prefix is present" do
    captured = call_with_env "/boards"

    assert_equal "", captured.fetch(:script_name)
    assert_equal "/boards", captured.fetch(:path_info)
    assert_nil captured.fetch(:external_account_id)
    assert_nil captured.fetch(:current_account)
  end

  test "encodes account IDs without zero-padding" do
    assert_equal "1", AccountSlug.encode(1)
  end

  test "decodes both padded and non-padded slugs" do
    assert_equal 123, AccountSlug.decode("123")
    assert_equal 123, AccountSlug.decode("0000123")
  end

  private
    def call_with_env(path, extra_env = {})
      captured = {}
      extra_env = { "action_dispatch.routes" => Rails.application.routes }.merge(extra_env)

      app = ->(env) do
        captured[:script_name] = env["SCRIPT_NAME"]
        captured[:path_info] = env["PATH_INFO"]
        captured[:external_account_id] = env["fizzy.external_account_id"]
        captured[:current_account] = Current.account
        [ 200, {}, [ "ok" ] ]
      end

      middleware = AccountSlug::Extractor.new(app)
      middleware.call Rack::MockRequest.env_for(path, extra_env.merge(method: "GET"))

      captured
    end
end
