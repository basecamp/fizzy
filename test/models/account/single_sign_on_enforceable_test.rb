require "test_helper"

class Account::SingleSignOnEnforceableTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @session = sessions(:kevin)
  end

  teardown do
    disable_single_sign_on
  end

  test "accessible with any session when single sign-on is not configured" do
    @account.update!(single_sign_on_group: "/engineering/fizzy")

    assert @account.accessible_with?(@session)
    assert @account.accessible_with?(nil)
  end

  test "accessible only with a recent single sign-on session when single sign-on is configured" do
    enable_single_sign_on

    assert_not @account.accessible_with?(nil)
    assert_not @account.accessible_with?(@session)

    @session.update!(single_sign_on_authenticated_at: 1.hour.ago)
    assert @account.accessible_with?(@session)

    @session.update!(single_sign_on_authenticated_at: 13.hours.ago)
    assert_not @account.accessible_with?(@session)
  end

  test "accessible only with a session in the group" do
    enable_single_sign_on
    @account.update!(single_sign_on_group: "/engineering/fizzy")

    @session.update!(single_sign_on_authenticated_at: 1.hour.ago, single_sign_on_groups: [ "/engineering" ])
    assert_not @account.accessible_with?(@session)

    @session.update!(single_sign_on_groups: [ "/engineering", "/engineering/fizzy" ])
    assert @account.accessible_with?(@session)
  end

  test "accessible with a session in a subgroup of the group" do
    enable_single_sign_on
    @account.update!(single_sign_on_group: "/engineering")

    @session.update!(single_sign_on_authenticated_at: 1.hour.ago, single_sign_on_groups: [ "/engineering/fizzy" ])
    assert @account.accessible_with?(@session)
  end

  test "accessible with a session in the admin group" do
    enable_single_sign_on admin_group: "/fizzy/admin"
    @account.update!(single_sign_on_group: "/engineering/fizzy")

    @session.update!(single_sign_on_authenticated_at: 1.hour.ago, single_sign_on_groups: [ "/fizzy/admin" ])
    assert @account.accessible_with?(@session)
  end

  test "group is normalized" do
    @account.update!(single_sign_on_group: "  /engineering/fizzy ")
    assert_equal "/engineering/fizzy", @account.single_sign_on_group

    @account.update!(single_sign_on_group: " ")
    assert_nil @account.single_sign_on_group
  end

  test "group must be a full path" do
    [ "fizzy", "/", "/fizzy/", "//fizzy", "/fizzy//engineering" ].each do |group|
      assert_not @account.update(single_sign_on_group: group), group
      assert_equal [ "Enter the full group path, such as /sales" ], @account.errors.full_messages
    end
  end

  test "admin group of the account" do
    assert_nil @account.single_sign_on_admin_group

    enable_single_sign_on account_admin_subgroup: "admin"
    assert_nil @account.single_sign_on_admin_group

    @account.single_sign_on_group = "/fizzy/engineering"
    assert_equal "/fizzy/engineering/admin", @account.single_sign_on_admin_group
  end

  test "role for groups" do
    enable_single_sign_on admin_group: "/fizzy/admin", account_admin_subgroup: "admin"
    @account.single_sign_on_group = "/fizzy/engineering"

    assert_equal "admin", @account.single_sign_on_role_for([ "/fizzy/admin" ])
    assert_equal "admin", @account.single_sign_on_role_for([ "/fizzy/engineering/admin" ])
    assert_equal "member", @account.single_sign_on_role_for([ "/fizzy/engineering" ])
    assert_equal "member", @account.single_sign_on_role_for([ "/sales/admin" ])
  end

  test "a new group sets roles from the newest single sign-on groups" do
    enable_single_sign_on admin_group: "/fizzy/admin", account_admin_subgroup: "admin"
    identities(:kevin).sessions.create!(single_sign_on_authenticated_at: 1.hour.ago, single_sign_on_groups: [ "/sales/admin" ])
    sessions(:kevin).update!(single_sign_on_authenticated_at: Time.current, single_sign_on_groups: [ "/engineering/admin", "/sales" ])
    sessions(:jz).update!(single_sign_on_authenticated_at: Time.current, single_sign_on_groups: [ "/sales/admin" ])
    sessions(:david).update!(single_sign_on_authenticated_at: Time.current, single_sign_on_groups: [ "/fizzy/admin" ])

    @account.update!(single_sign_on_group: "/engineering")
    assert_equal "admin", users(:kevin).reload.role
    assert_equal "member", users(:jz).reload.role

    @account.update!(single_sign_on_group: "/sales")
    assert_equal "member", users(:kevin).reload.role
    assert_equal "admin", users(:jz).reload.role
    assert_equal "admin", users(:david).reload.role
    assert_equal "owner", users(:jason).reload.role
  end

  test "a new group keeps roles without single sign-on" do
    @account.update!(single_sign_on_group: "/sales")

    assert_equal "admin", users(:kevin).reload.role
    assert_equal "member", users(:jz).reload.role
  end

  test "joinable by single sign-on with the account group" do
    @account.update!(single_sign_on_group: "/engineering/fizzy")

    with_multi_tenant_mode(false) do
      assert_includes Account.joinable_by_single_sign_on([ "/engineering/fizzy" ]), @account
      assert_not_includes Account.joinable_by_single_sign_on([ "/engineering" ]), @account
      assert_empty Account.joinable_by_single_sign_on([])
    end
  end

  test "joinable by single sign-on with a subgroup of the account group" do
    @account.update!(single_sign_on_group: "/engineering")

    with_multi_tenant_mode(false) do
      assert_includes Account.joinable_by_single_sign_on([ "/engineering/fizzy" ]), @account
    end
  end

  test "group must fit in 255 characters" do
    group = "/#{"a" * 254}"
    assert @account.update(single_sign_on_group: group)

    assert_not @account.update(single_sign_on_group: "#{group}a")
    assert_equal [ "Enter a group path of 255 characters or fewer" ], @account.errors.full_messages
  end

  test "joinable by single sign-on compares groups exactly" do
    @account.update!(single_sign_on_group: "/Sales")

    assert_includes Account.joinable_by_single_sign_on([ "/Sales" ]), @account
    assert_not_includes Account.joinable_by_single_sign_on([ "/sales" ]), @account
  end

  test "every account is joinable by a member of the admin group" do
    enable_single_sign_on admin_group: "/fizzy/admin"

    with_multi_tenant_mode(true) do
      assert_equal Account.active.ids.sort, Account.joinable_by_single_sign_on([ "/fizzy/admin" ]).ids.sort
    end
  end

  test "joinable by single sign-on in multi-tenant mode" do
    @account.update!(single_sign_on_group: "/engineering/fizzy")

    with_multi_tenant_mode(true) do
      assert_includes Account.joinable_by_single_sign_on([ "/engineering/fizzy" ]), @account
    end
  end

  test "changing the group reconnects the account users" do
    User.any_instance.expects(:close_remote_connections).with(reconnect: true).at_least_once
    @account.update!(single_sign_on_group: "/engineering/fizzy")
  end

  test "other changes do not reconnect the account users" do
    User.any_instance.expects(:close_remote_connections).never
    @account.update!(name: "Renamed")
  end
end
