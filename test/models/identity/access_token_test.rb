require "test_helper"

class Identity::AccessTokenTest < ActiveSupport::TestCase
  test "new access token comes with a session" do
    access_token = identities(:david).access_tokens.create!
    assert_equal "Access Token", identities(:david).sessions.last.user_agent
  end
end
