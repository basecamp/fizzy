require "test_helper"

class LinkTest < ActiveSupport::TestCase
  include VcrTestHelper

  test "unfurl" do
    user = users(:kevin)
    link = Link.new("http://3.basecamp.localhost:3001/181900405/buckets/1042979247/messages/783526101")

    assert_changes -> { link.metadata }, from: nil do
      link.unfurl(user: user)
    end

    assert_kind_of Link::Metadata, link.metadata
  end
end
