require "test_helper"

class User::ConfigurableTest < ActiveSupport::TestCase
  test "should create settings for new users" do
    user = User.create! name: "Some new user"
    assert user.settings.present?
  end
end
