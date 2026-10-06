require "test_helper"

class SingleSignOn::ClaimsTest < ActiveSupport::TestCase
  test "from payload" do
    claims = SingleSignOn::Claims.from_payload(
      "iss" => SINGLE_SIGN_ON_ISSUER, "sub" => "subject", "email" => "kevin@37signals.com",
      "email_verified" => true, "name" => "Kevin Fizz")

    assert_equal SINGLE_SIGN_ON_ISSUER, claims.issuer
    assert_equal "subject", claims.subject
    assert_equal "kevin@37signals.com", claims.email_address
    assert_equal "Kevin Fizz", claims.name
    assert claims.email_verified?
  end

  test "name from given and family names" do
    assert_equal "Kevin Fizz", claims_from("given_name" => "Kevin", "family_name" => "Fizz").name
    assert_equal "Kevin", claims_from("given_name" => "Kevin").name
    assert_nil claims_from({}).name
  end

  test "long names are cut" do
    assert_equal SingleSignOn::Claims::NAME_LENGTH_LIMIT, claims_from("name" => "K" * 500).name.length
  end

  test "groups" do
    assert_equal [ "/engineering/fizzy", "/sales" ], claims_from("groups" => [ "/engineering/fizzy", "/sales", "/sales", 7 ]).groups
    assert_equal [ "/engineering" ], claims_from("groups" => "/engineering").groups
    assert_equal [], claims_from({}).groups
  end

  test "a group name without a leading slash is a top-level group" do
    assert_equal [ "/fizzy-admins", "/parent/child", "/sales" ],
      claims_from("groups" => [ "fizzy-admins", "parent/child", "/sales", "sales", "" ]).groups
  end

  test "groups default to none" do
    assert_equal [], SingleSignOn::Claims.new(issuer: "issuer", subject: "subject", email_address: nil, email_verified: nil, name: nil).groups
  end

  test "email is verified only for a true claim and an email address" do
    assert_not claims_from("email" => "kevin@37signals.com", "email_verified" => "true").email_verified?
    assert_not claims_from("email" => "kevin@37signals.com").email_verified?
    assert_not claims_from("email_verified" => true).email_verified?
  end

  private
    def claims_from(payload)
      SingleSignOn::Claims.from_payload({ "iss" => SINGLE_SIGN_ON_ISSUER, "sub" => "subject" }.merge(payload))
    end
end
