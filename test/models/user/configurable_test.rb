require "test_helper"

class User::ConfigurableTest < ActiveSupport::TestCase
  test "should create settings for new users" do
    user = User.create! account: accounts("37s"), name: "Some new user"
    assert user.settings.present?
  end
end
