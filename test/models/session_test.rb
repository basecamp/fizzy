require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @session = sessions(:kevin)
  end

  teardown do
    disable_single_sign_on
  end

  test "recently authenticated by single sign-on" do
    assert_not @session.recently_authenticated_by_single_sign_on?

    @session.single_sign_on_authenticated_at = 11.hours.ago
    assert @session.recently_authenticated_by_single_sign_on?

    @session.single_sign_on_authenticated_at = 13.hours.ago
    assert_not @session.recently_authenticated_by_single_sign_on?
  end

  test "single sign-on groups" do
    assert_equal [], @session.single_sign_on_groups
    assert_not @session.single_sign_on_group?("/engineering/fizzy")

    @session.update!(single_sign_on_groups: [ "/engineering/fizzy" ])

    assert @session.reload.single_sign_on_group?("/engineering/fizzy")
    assert @session.single_sign_on_group?("/engineering")
    assert_not @session.single_sign_on_group?("/sales")
  end

  test "single sign-on admin and account creator" do
    enable_single_sign_on admin_group: "/fizzy/admin"
    assert_not @session.single_sign_on_admin?
    assert_not @session.single_sign_on_account_creator?

    @session.single_sign_on_groups = [ "/fizzy/admin" ]
    assert @session.single_sign_on_admin?
    assert @session.single_sign_on_account_creator?
  end

  test "recently authenticated by single sign-on follows the configured period" do
    enable_single_sign_on reauthentication_hours: "2"

    @session.single_sign_on_authenticated_at = 1.hour.ago
    assert @session.recently_authenticated_by_single_sign_on?

    @session.single_sign_on_authenticated_at = 3.hours.ago
    assert_not @session.recently_authenticated_by_single_sign_on?
  end
end
