require "fizzy/saas/version"
require "fizzy/saas/engine"

module Fizzy
  module Saas
    def self.append_test_paths
      engine_test_path = Engine.root.join("test")
      ENV["DEFAULT_TEST"] = "{#{engine_test_path},test}/**/*_test.rb"
      ENV["DEFAULT_TEST_EXCLUDE"] = "{#{engine_test_path},test}/{system,dummy,fixtures}/**/*_test.rb"
    end
  end
end
