require "test_helper"

class SingleSignOnTest < ActiveSupport::TestCase
  teardown do
    disable_single_sign_on
  end

  test "configured with an issuer, a client ID, and a client secret" do
    assert_not SingleSignOn.configured?

    enable_single_sign_on
    assert SingleSignOn.configured?
  end

  test "partial configuration is invalid" do
    enable_single_sign_on client_secret: nil

    assert_not SingleSignOn.configured?
    assert_raises(SingleSignOn::ConfigurationError) { SingleSignOn.ensure_valid_configuration }
  end

  test "no configuration is valid" do
    assert_nothing_raised { SingleSignOn.ensure_valid_configuration }
  end

  test "issuer must use https outside development and test" do
    enable_single_sign_on issuer: "http://id.example.com"
    assert_nothing_raised { SingleSignOn.ensure_valid_configuration }

    Rails.env.stubs(:local?).returns(false)
    assert_raises(SingleSignOn::ConfigurationError) { SingleSignOn.ensure_valid_configuration }
  end

  test "issuer must be a URL with a host" do
    [ "https:", "https:///realms/acme", "https://id example.com", "id.example.com" ].each do |issuer|
      enable_single_sign_on issuer: issuer
      assert_raises(SingleSignOn::ConfigurationError, issuer) { SingleSignOn.ensure_valid_configuration }
    end
  end

  test "reauthentication period" do
    assert_equal 12.hours, SingleSignOn.reauthentication_period

    enable_single_sign_on reauthentication_hours: "3"
    assert_equal 3.hours, SingleSignOn.reauthentication_period
  end

  test "reauthentication hours must be a whole number of 1 or more" do
    [ "0", "-2", "abc", "1.5" ].each do |hours|
      enable_single_sign_on reauthentication_hours: hours
      assert_raises(SingleSignOn::ConfigurationError, hours) { SingleSignOn.ensure_valid_configuration }
    end
  end

  test "admin group" do
    assert_nil SingleSignOn.admin_group

    enable_single_sign_on admin_group: " /fizzy/admin "
    assert_equal "/fizzy/admin", SingleSignOn.admin_group
  end

  test "admin group must be a full path" do
    [ "fizzy/admin", "/", "/fizzy/admin/", "/fizzy//admin" ].each do |group|
      enable_single_sign_on admin_group: group
      assert_raises(SingleSignOn::ConfigurationError, group) { SingleSignOn.ensure_valid_configuration }
    end

    enable_single_sign_on admin_group: "/fizzy/admin"
    assert_nothing_raised { SingleSignOn.ensure_valid_configuration }
  end

  test "account admin subgroup must be a relative path" do
    [ "/admin", "admin/", "admin//owners" ].each do |subgroup|
      enable_single_sign_on account_admin_subgroup: subgroup
      assert_raises(SingleSignOn::ConfigurationError, subgroup) { SingleSignOn.ensure_valid_configuration }
    end

    enable_single_sign_on account_admin_subgroup: " admin "
    assert_nothing_raised { SingleSignOn.ensure_valid_configuration }
    assert_equal "admin", SingleSignOn.account_admin_subgroup
  end

  test "a member of a subgroup is a member of its parent groups" do
    groups = [ "/fizzy/engineering/admin" ]

    assert SingleSignOn.member?(groups, "/fizzy/engineering/admin")
    assert SingleSignOn.member?(groups, "/fizzy/engineering")
    assert SingleSignOn.member?(groups, "/fizzy")
    assert_not SingleSignOn.member?(groups, "/fizzy/engineering/admin/leads")
    assert_not SingleSignOn.member?(groups, "/fizzy/eng")
    assert_not SingleSignOn.member?([ "/europe/sales" ], "/sales")
  end

  test "admins are members of the admin group" do
    assert_not SingleSignOn.admin?([ "/fizzy/admin" ])

    enable_single_sign_on admin_group: "/fizzy/admin"
    assert SingleSignOn.admin?([ "/sales", "/fizzy/admin" ])
    assert SingleSignOn.admin?([ "/fizzy/admin/leads" ])
    assert_not SingleSignOn.admin?([ "/fizzy" ])
  end

  test "account creators are members of the admin group" do
    enable_single_sign_on admin_group: "/fizzy/admin"

    assert SingleSignOn.account_creator?([ "/fizzy/admin" ])
    assert_not SingleSignOn.account_creator?([ "/sales" ])
  end

  test "without an admin group only the first account can be created" do
    enable_single_sign_on

    assert_not SingleSignOn.account_creator?([ "/fizzy/admin" ])

    Account.stubs(:none?).returns(true)
    assert SingleSignOn.account_creator?([])
  end

  test "provider name" do
    assert_equal "SSO", SingleSignOn.provider_name

    enable_single_sign_on provider_name: "Acme SSO"
    assert_equal "Acme SSO", SingleSignOn.provider_name
  end

  test "provider" do
    enable_single_sign_on

    provider = SingleSignOn.provider
    assert_equal SINGLE_SIGN_ON_ISSUER, provider.issuer
    assert_equal SINGLE_SIGN_ON_CLIENT_ID, provider.client_id
  end
end
