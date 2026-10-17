require "test_helper"

class Identity::SingleSignOnLinkableTest < ActiveSupport::TestCase
  teardown do
    disable_single_sign_on
  end

  test "find by single sign-on" do
    assert_equal identities(:jz), Identity.find_by_single_sign_on(single_sign_on_claims(subject: "jz-subject"))
    assert_nil Identity.find_by_single_sign_on(single_sign_on_claims(subject: "unknown-subject"))
    assert_nil Identity.find_by_single_sign_on(single_sign_on_claims(issuer: "https://other.example.com", subject: "jz-subject"))
  end

  test "latest single sign-on groups come from the current issuer" do
    enable_single_sign_on
    identity = identities(:kevin)
    identity.sessions.create!(single_sign_on_authenticated_at: 1.hour.ago, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER, single_sign_on_groups: [ "/sales" ])
    identity.sessions.create!(single_sign_on_authenticated_at: Time.current, single_sign_on_issuer: "https://other.example.com", single_sign_on_groups: [ "/fizzy/admin" ])

    assert_equal [ "/sales" ], identity.latest_single_sign_on_groups
  end

  test "find by single sign-on compares the issuer and the subject exactly" do
    assert_nil Identity.find_by_single_sign_on(single_sign_on_claims(subject: "JZ-subject"))
    assert_nil Identity.find_by_single_sign_on(single_sign_on_claims(subject: "jz-subjéct"))
    assert_nil Identity.find_by_single_sign_on(single_sign_on_claims(issuer: "https://ID.example.com", subject: "jz-subject"))

    assert_nothing_raised { identities(:kevin).link_single_sign_on(single_sign_on_claims(subject: "JZ-subject")) }
  end

  test "link single sign-on" do
    identity = identities(:kevin)
    identity.link_single_sign_on(single_sign_on_claims(subject: "kevin-subject"))

    assert identity.single_sign_on_linked?
    assert_equal "kevin-subject", identity.single_sign_on_link_for(SINGLE_SIGN_ON_ISSUER).subject
    assert_nil identity.single_sign_on_link_for("https://other.example.com")
  end

  test "a subject links to one identity" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      identities(:kevin).link_single_sign_on(single_sign_on_claims(subject: "jz-subject"))
    end
  end

  test "an identity links to one subject for each issuer" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      identities(:jz).link_single_sign_on(single_sign_on_claims(subject: "another-subject"))
    end
  end

  test "join the accounts of the groups" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")
    identity = identities(:mike)

    with_multi_tenant_mode(false) do
      identity.join_accounts_joinable_by_single_sign_on(name: "Mike Fizz", groups: [ "/engineering/fizzy" ])
    end

    user = identity.users.find_by!(account: accounts("37s"))
    assert user.member?
    assert user.verified?
    assert_equal "Mike Fizz", user.name
  end

  test "join no account without its group" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")

    assert_no_difference -> { User.count } do
      with_multi_tenant_mode(false) do
        identities(:mike).join_accounts_joinable_by_single_sign_on(name: "Mike", groups: [ "/engineering" ])
        identities(:mike).join_accounts_joinable_by_single_sign_on(name: "Mike", groups: [])
      end
    end
  end

  test "join skips accounts with a user" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")

    assert_no_difference -> { User.count } do
      with_multi_tenant_mode(false) do
        identities(:kevin).join_accounts_joinable_by_single_sign_on(name: "Kevin", groups: [ "/engineering/fizzy" ])
      end
    end

    assert users(:kevin).reload.admin?
  end

  test "update roles from single sign-on" do
    enable_single_sign_on account_admin_subgroup: "admin"
    accounts("37s").update!(single_sign_on_group: "/engineering")

    identities(:jz).update_roles_from_single_sign_on([ "/engineering/admin" ])
    assert users(:jz).reload.admin?

    identities(:jz).update_roles_from_single_sign_on([ "/engineering" ])
    assert users(:jz).reload.member?
  end

  test "update roles keeps the owner" do
    identities(:jason).update_roles_from_single_sign_on([])

    assert users(:jason).reload.owner?
  end

  test "links are deleted with the identity" do
    assert_difference -> { Identity::SingleSignOnLink.count }, -1 do
      identities(:jz).destroy
    end
  end
end
