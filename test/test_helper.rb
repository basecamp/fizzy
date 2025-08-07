ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "vcr"
require "signal_id/testing"
require "queenbee/testing/mocks"
require "mocha/minitest"

WebMock.allow_net_connect!

VCR.configure do |config|
  config.allow_http_connections_when_no_cassette = true
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<OPEN_API_KEY>") { Rails.application.credentials.openai_api_key || ENV["OPEN_AI_API_KEY"] }
  config.default_cassette_options = {
    match_requests_on: [ :method, :uri, :body ]
  }
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActiveJob::TestHelper
    include SignalId::Testing
    include ActionTextTestHelper, CardTestHelper, ChangeTestHelper, SessionTestHelper

    def with_local_auth
      begin
        old_local_auth = Rails.application.config.x.local_authentication
        Rails.application.config.x.local_authentication = true
        yield
      ensure
        Rails.application.config.x.local_authentication = old_local_auth
      end
    end
  end
end

RubyLLM.configure do |config|
  config.openai_api_key ||= "DUMMY-TEST-KEY" # Run tests with VCR without having to configure OpenAI API key locally.
end

Queenbee::Remote::Account.class_eval do
  # because we use the account ID as the tenant name, we need it to be unique in each test to avoid
  # parallelized tests clobbering each other.
  def next_id
    super + Random.rand(1000000)
  end
end
