require "test_helper"

class SingleSignOn::AuthenticationTest < ActiveSupport::TestCase
  teardown do
    disable_single_sign_on
  end

  test "find an identity by its link" do
    authentication = authenticate(subject: "jz-subject", email_address: "other@example.com", email_verified: false)

    assert authentication.sign_in
    assert_equal identities(:jz), authentication.identity
    assert_nil authentication.failure_message
  end

  test "link an existing identity by a confirmed email address" do
    authentication = authenticate(subject: "kevin-subject", email_address: "Kevin@37signals.com")

    assert authentication.sign_in
    assert_equal identities(:kevin), authentication.identity
    assert_equal "kevin-subject", identities(:kevin).single_sign_on_link_for(SINGLE_SIGN_ON_ISSUER).subject
  end

  test "refuse an email address that is not confirmed" do
    authentication = authenticate(email_address: "kevin@37signals.com", email_verified: false)

    assert_no_difference -> { Identity::SingleSignOnLink.count } do
      assert_not authentication.sign_in
    end

    assert_nil authentication.identity
    assert_match "not confirmed", authentication.failure_message
  end

  test "refuse an identity linked to a different subject" do
    authentication = authenticate(subject: "another-subject", email_address: identities(:jz).email_address)

    assert_not authentication.sign_in
    assert_match "linked to a different", authentication.failure_message
  end

  test "refuse an email address that is not valid" do
    authentication = authenticate(email_address: "not an email address")

    assert_no_difference -> { Identity.count } do
      assert_not authentication.sign_in
    end

    assert_match "not valid", authentication.failure_message
  end

  test "create an identity for a member of the admin group" do
    enable_single_sign_on admin_group: "/fizzy/admin"
    authentication = authenticate(email_address: "newcomer@example.com", groups: [ "/fizzy/admin" ])

    assert_difference -> { Identity.count }, +1 do
      assert authentication.sign_in
    end

    assert_equal "newcomer@example.com", authentication.identity.email_address
    assert authentication.identity.single_sign_on_linked?
  end

  test "create an identity for the first person on a new server" do
    Account.stubs(:none?).returns(true)
    authentication = authenticate(email_address: "newcomer@example.com")

    assert authentication.sign_in
    assert authentication.requires_signup_completion?
  end

  test "create nothing outside the admin group in multi-tenant mode" do
    enable_single_sign_on admin_group: "/fizzy/admin"
    authentication = authenticate(email_address: "newcomer@example.com", groups: [ "/sales" ])

    with_multi_tenant_mode(true) do
      assert_no_difference [ "Identity.count", "User.count" ] do
        assert_not authentication.sign_in
      end
    end

    assert_match "do not have access", authentication.failure_message
  end

  test "create nothing when the person has no account to join" do
    authentication = authenticate(email_address: "newcomer@example.com")

    with_multi_tenant_mode(false) do
      assert_no_difference [ "Identity.count", "Identity::SingleSignOnLink.count", "User.count" ] do
        assert_not authentication.sign_in
      end
    end

    assert_nil authentication.identity
    assert_match "do not have access", authentication.failure_message
  end

  test "keep no link when an existing identity has no account" do
    identity = Identity.create!(email_address: "newcomer@example.com")
    authentication = authenticate(email_address: identity.email_address)

    with_multi_tenant_mode(false) do
      assert_not authentication.sign_in
    end

    assert_not identity.reload.single_sign_on_linked?
  end

  test "join the accounts of the groups" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")
    authentication = authenticate(email_address: "newcomer@example.com", name: "New Comer", groups: [ "/engineering/fizzy" ])

    with_multi_tenant_mode(false) do
      assert authentication.sign_in
      assert_not authentication.requires_signup_completion?
    end

    user = authentication.identity.users.find_by!(account: accounts("37s"))
    assert user.member?
    assert user.verified?
    assert user.setup?
    assert_equal "New Comer", user.name
  end

  test "join at every sign-in" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")
    identities(:mike).link_single_sign_on(single_sign_on_claims(subject: "mike-subject"))

    with_multi_tenant_mode(false) do
      assert_difference -> { User.count }, +1 do
        assert authenticate(subject: "mike-subject", groups: [ "/engineering/fizzy" ]).sign_in
      end
    end

    assert identities(:mike).users.find_by!(account: accounts("37s")).member?
  end

  test "join no account without its group" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")

    with_multi_tenant_mode(false) do
      assert_no_difference -> { User.count } do
        authenticate(subject: "mike-subject", email_address: identities(:mike).email_address, groups: [ "/sales" ]).sign_in
      end
    end
  end

  test "a removed person joins again at the next sign-in" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")
    users(:jz).deactivate

    with_multi_tenant_mode(false) do
      assert authenticate(subject: "jz-subject", groups: [ "/engineering/fizzy" ]).sign_in
    end

    assert identities(:jz).users.active.exists?(account: accounts("37s"))
  end

  test "a member of the admin group joins every account as an admin" do
    enable_single_sign_on admin_group: "/fizzy/admin"
    accounts("37s").update!(single_sign_on_group: "/fizzy/engineering")
    authentication = authenticate(email_address: "newcomer@example.com", groups: [ "/fizzy/admin" ])

    with_multi_tenant_mode(true) do
      assert authentication.sign_in
    end

    users = authentication.identity.users
    assert_equal Account.active.ids.sort, users.pluck(:account_id).sort
    assert users.all?(&:admin?)
  end

  test "the account admin subgroup makes a person an admin of that account" do
    enable_single_sign_on account_admin_subgroup: "admin"
    accounts("37s").update!(single_sign_on_group: "/fizzy/engineering")

    assert authenticate(subject: "jz-subject", groups: [ "/fizzy/engineering/admin" ]).sign_in

    assert users(:jz).reload.admin?
  end

  test "a person outside the admin groups becomes a member" do
    enable_single_sign_on admin_group: "/fizzy/admin", account_admin_subgroup: "admin"
    accounts("37s").update!(single_sign_on_group: "/fizzy/engineering")
    users(:jz).update!(role: :admin)

    assert authenticate(subject: "jz-subject", groups: [ "/fizzy/engineering" ]).sign_in

    assert users(:jz).reload.member?
  end

  test "the owner stays the owner" do
    assert authenticate(email_address: identities(:jason).email_address).sign_in

    assert users(:jason).reload.owner?
  end

  test "retry once when two sign-ins link at the same time" do
    Identity.any_instance.expects(:link_single_sign_on).twice
      .raises(ActiveRecord::RecordNotUnique).then.returns(true)

    authentication = authenticate(email_address: "kevin@37signals.com")

    assert authentication.sign_in
    assert_equal identities(:kevin), authentication.identity
  end

  private
    def authenticate(**claims)
      SingleSignOn::Authentication.new(single_sign_on_claims(**claims))
    end
end
