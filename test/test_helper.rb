ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# there's no fixture for this, we're just generating a stable integer
Rails.application.config.active_record_tenanted.default_tenant = ActiveRecord::FixtureSet.identify "37s_fizzy"

require "rails/test_help"
require "webmock/minitest"
require "vcr"
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

  # Ignore timestamps in request bodies
  config.before_record do |i|
    if i.request&.body
      i.request.body.gsub!(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/, "<TIME>")
    end
  end

  config.register_request_matcher :body_without_times do |r1, r2|
    b1 = (r1.body || "").gsub(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/, "<TIME>")
    b2 = (r2.body || "").gsub(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/, "<TIME>")
    b1 == b2
  end

  config.default_cassette_options = {
    match_requests_on: [ :method, :uri, :body_without_times ]
  }
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActiveJob::TestHelper
    include ActionTextTestHelper, CardTestHelper, ChangeTestHelper, SessionTestHelper
  end
end

class ActionDispatch::IntegrationTest
  setup do
    integration_session.default_url_options[:script_name] = "/#{ApplicationRecord.current_tenant}"
  end
end

class ActionDispatch::SystemTestCase
  setup do
    self.default_url_options[:script_name] = "/#{ApplicationRecord.current_tenant}"
  end
end

RubyLLM.configure do |config|
  config.openai_api_key ||= "DUMMY-TEST-KEY" # Run tests with VCR without having to configure OpenAI API key locally.
end

unless Rails.application.config.x.oss_config
  load File.expand_path("../gems/fizzy-saas/test/test_helper.rb", __dir__)
end
