ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "vcr"

WebMock.allow_net_connect!

VCR.configure do |config|
  config.allow_http_connections_when_no_cassette = true
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<OPEN_API_KEY>") { Rails.application.credentials.openai_api_key || ENV["OPEN_AI_API_KEY"] }
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActiveJob::TestHelper
    include CardTestHelper, ChangeTestHelper, SessionTestHelper
  end
end

RubyLLM.configure do |config|
  config.openai_api_key ||= "DUMMY-TEST-KEY" # Run tests with VCR without having to configure OpenAI API key locally.
end
