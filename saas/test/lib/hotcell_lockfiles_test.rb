require "test_helper"
require "bundler"

# The app and the cell resolve hotcell separately, against the same moving branch. A skew between the
# client the app loads and the server the cell runs is a `protocol` failure at runtime, on every request.
class HotcellLockfilesTest < ActiveSupport::TestCase
  test "the app's lockfile and the cell's name the same hotcell revision" do
    assert_equal hotcell_revision("Gemfile.saas.lock"), hotcell_revision("saas/hotcell/Gemfile.lock")
  end

  private
    def hotcell_revision(lockfile)
      path = Rails.root.join(lockfile)
      source = Bundler::LockfileParser.new(path.read).sources.find { it.uri.to_s.include?("basecamp/hotcell") }

      assert_not_nil source, "#{lockfile} names no hotcell source"
      source.revision
    end
end
