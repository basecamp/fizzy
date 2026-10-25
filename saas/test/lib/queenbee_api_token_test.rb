require "test_helper"

# The engine sets Queenbee's API tokens from the environment in a to_prepare block, so each test
# re-runs the prepare callbacks under the environment it needs.
class QueenbeeApiTokenTest < ActiveSupport::TestCase
  setup do
    @token, @previous_token = Queenbee::ApiToken.token, Queenbee::ApiToken.previous_token
  end

  teardown do
    Queenbee::ApiToken.token, Queenbee::ApiToken.previous_token = @token, @previous_token
  end

  test "during a rotation the previous token is accepted alongside the current one" do
    prepare_with "QUEENBEE_API_TOKEN" => "current-token", "QUEENBEE_API_TOKEN_PREVIOUS" => "previous-token"

    assert Queenbee::ApiToken.valid?("current-token")
    assert Queenbee::ApiToken.valid?("previous-token")
    assert_not Queenbee::ApiToken.valid?("some-other-token")
  end

  test "without a previous token only the current one is accepted" do
    prepare_with "QUEENBEE_API_TOKEN" => "current-token", "QUEENBEE_API_TOKEN_PREVIOUS" => nil

    assert_nil Queenbee::ApiToken.previous_token
    assert Queenbee::ApiToken.valid?("current-token")
    assert_not Queenbee::ApiToken.valid?("")
  end

  private
    def prepare_with(vars)
      with_env(vars) { Rails.application.reloader.prepare! }
    end

    def with_env(vars)
      originals = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| ENV[key] = value }
      yield
    ensure
      originals.each { |key, value| ENV[key] = value }
    end
end
