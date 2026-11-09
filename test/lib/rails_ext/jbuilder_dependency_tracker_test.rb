require "test_helper"

class JbuilderDependencyTrackerTest < ActiveSupport::TestCase
  test "a cached JSON fragment's digest covers the partials it renders" do
    lookup_context = ApplicationController.new.lookup_context.tap { |context| context.formats = [ :json ] }
    dependencies = ActionView::Digestor.tree("activities/_activity", lookup_context, true).children.map(&:name)

    assert_equal %w[ boards/board cards/card cards/comments/comment users/user ], dependencies.sort
  end
end
