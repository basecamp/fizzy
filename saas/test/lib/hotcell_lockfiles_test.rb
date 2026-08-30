require "test_helper"
require "bundler"

# The app and the cell resolve hotcell separately. A skew between the client the app loads and the
# server the cell runs is a `protocol` failure at runtime, on every request. hotcell-core is the anchor
# because both sides depend on it with an exact constraint.
class HotcellLockfilesTest < ActiveSupport::TestCase
  test "the app's lockfile and the cell's name the same hotcell version" do
    assert_equal hotcell_version("Gemfile.saas.lock"), hotcell_version("saas/hotcell/Gemfile.lock")
  end

  test "neither lockfile resolves hotcell from a git source" do
    %w[ Gemfile.saas.lock saas/hotcell/Gemfile.lock ].each do |lockfile|
      source = parsed(lockfile).sources.find { it.to_s.include?("hotcell") }

      assert_nil source, "#{lockfile} still resolves hotcell from #{source}"
    end
  end

  private
    def parsed(lockfile)
      Bundler::LockfileParser.new(Rails.root.join(lockfile).read)
    end

    def hotcell_version(lockfile)
      spec = parsed(lockfile).specs.find { it.name == "hotcell-core" }

      assert_not_nil spec, "#{lockfile} names no hotcell-core"
      spec.version
    end
end
