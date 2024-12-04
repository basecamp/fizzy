ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include SessionTestHelper

    parallelize_setup do |j|
      dbname = "test-tenant-#{j}"
      Tenant.create_with(dbname: dbname).find_or_create_by!(slug: "default")
      ApplicationRecord.connecting_to(shard: dbname)
    end
  end
end

Tenant.create_with(dbname: "test").find_or_create_by!(slug: "default")
ApplicationRecord.connecting_to(shard: "test")
