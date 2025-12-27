require "queenbee/testing/mocks"

Queenbee::Remote::Account.class_eval do
  # because we use the account ID as the tenant name, we need it to be unique in each test to avoid
  # parallelized tests clobbering each other.
  def next_id
    super + Random.rand(1000000)
  end
end

# Add engine fixtures to the test fixture paths
module Fizzy::Saas::EngineFixtures
  def included(base)
    super
    engine_fixtures = Fizzy::Saas::Engine.root.join("test", "fixtures").to_s
    base.fixture_paths << engine_fixtures unless base.fixture_paths.include?(engine_fixtures)
  end
end

ActiveRecord::TestFixtures.singleton_class.prepend(Fizzy::Saas::EngineFixtures)
