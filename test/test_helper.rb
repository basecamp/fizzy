ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

require "rails/test_help"
require "webmock/minitest"
require "vcr"
require "mocha/minitest"
require "turbo/broadcastable/test_helper"

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
    include Turbo::Broadcastable::TestHelper

    setup do
      Current.account = accounts("37s")
    end

    teardown do
      Current.clear_all
    end
  end
end

class ActionDispatch::IntegrationTest
  setup do
    integration_session.default_url_options[:script_name] = "/#{ActiveRecord::FixtureSet.identify("37signals")}"
  end
end

class ActionDispatch::SystemTestCase
  setup do
    self.default_url_options[:script_name] = "/#{ActiveRecord::FixtureSet.identify("37signals")}"
  end
end

module FixturesTestHelper
  extend ActiveSupport::Concern

  class_methods do
    def identify(label, column_type = :integer)
      if label.to_s.end_with?("_uuid")
        column_type = :uuid
        label = label.to_s.delete_suffix("_uuid")
      end

      # Rails passes :string for varchar columns, so handle both :uuid and :string
      return super(label, column_type) unless column_type.in?([ :uuid, :string ])
      generate_fixture_uuid(label)
    end

    private

    def generate_fixture_uuid(label)
      # Generate deterministic UUIDv7 for fixtures that sorts by fixture ID
      # This allows .first/.last to work as expected in tests
      # Use the same CRC32 algorithm as Rails' default fixture ID generation
      # so that UUIDs sort in the same order as integer IDs
      fixture_int = Zlib.crc32("fixtures/#{label}") % (2**30 - 1)

      # Translate the deterministic order into times in the past, so that records
      # created during test runs are also always newer than the fixtures.
      base_time = Time.utc(2024, 1, 1, 0, 0, 0)
      timestamp = base_time + (fixture_int / 1000.0)

      uuid_v7_with_timestamp(timestamp, label)
    end

    def uuid_v7_with_timestamp(time, seed_string)
      # Generate UUIDv7 with custom timestamp and deterministic random bits
      # Format: 48-bit timestamp_ms | 12-bit sub_ms_precision | 4-bit version | 62-bit random

      time_ms = time.to_f * 1000
      timestamp_ms = time_ms.to_i

      # 48-bit timestamp (milliseconds since epoch)
      bytes = []
      bytes[0] = (timestamp_ms >> 40) & 0xff
      bytes[1] = (timestamp_ms >> 32) & 0xff
      bytes[2] = (timestamp_ms >> 24) & 0xff
      bytes[3] = (timestamp_ms >> 16) & 0xff
      bytes[4] = (timestamp_ms >> 8) & 0xff
      bytes[5] = timestamp_ms & 0xff

      # Use the 12-bit rand_a field for sub-millisecond precision
      # Extract fractional milliseconds and convert to 12-bit value (0-4095)
      # This gives us ~0.244 microsecond precision
      frac_ms = time_ms - timestamp_ms
      sub_ms_precision = (frac_ms * 4096).to_i & 0xfff

      # Derive deterministic "random" bits from seed_string for the remaining random bits
      hash = Digest::MD5.hexdigest(seed_string)

      # 12-bit sub-ms precision + 4-bit version (0111 for v7)
      bytes[6] = ((sub_ms_precision >> 8) & 0x0f) | 0x70  # version 7
      bytes[7] = sub_ms_precision & 0xff

      # 2-bit variant (10) + 62-bit random
      rand_b = hash[3...19].to_i(16) & ((2**62) - 1)
      bytes[8] = ((rand_b >> 56) & 0x3f) | 0x80  # variant 10
      bytes[9] = (rand_b >> 48) & 0xff
      bytes[10] = (rand_b >> 40) & 0xff
      bytes[11] = (rand_b >> 32) & 0xff
      bytes[12] = (rand_b >> 24) & 0xff
      bytes[13] = (rand_b >> 16) & 0xff
      bytes[14] = (rand_b >> 8) & 0xff
      bytes[15] = rand_b & 0xff

      # Format as UUID string and convert to base36 (25 chars)
      uuid = "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % bytes
      hex = uuid.delete("-")
      hex.to_i(16).to_s(36).rjust(25, "0")
    end
  end
end

ActiveSupport.on_load(:active_record_fixture_set) do
  prepend(FixturesTestHelper)
end
