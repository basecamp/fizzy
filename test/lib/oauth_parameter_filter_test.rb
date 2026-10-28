require "test_helper"

class OauthParameterFilterTest < ActiveSupport::TestCase
  CREDENTIALS = %w[ code code_verifier access_token refresh_token subject_token device_code client_secret client_assertion token dpop ]

  test "every OAuth credential parameter is filtered from logs" do
    filtered = filter(CREDENTIALS.index_with { "secret-value" })

    CREDENTIALS.each do |name|
      assert_equal "[FILTERED]", filtered[name], "#{name} is logged"
    end
  end

  test "public authorization parameters stay readable" do
    public_parameters = { "code_challenge" => "challenge", "code_challenge_method" => "S256", "state" => "xyz", "client_id" => "abc", "redirect_uri" => "http://127.0.0.1/cb" }

    assert_equal public_parameters, filter(public_parameters)
  end

  private
    def filter(parameters)
      ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(parameters)
    end
end
