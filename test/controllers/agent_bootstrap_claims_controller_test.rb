require "test_helper"

class AgentBootstrapClaimsControllerTest < ActionDispatch::IntegrationTest
  test "claim creates identity user access token and board watching access" do
    bootstrap = boards(:private).agent_bootstraps.create!(
      account: accounts("37s"),
      creator: users(:kevin),
      expires_at: 30.minutes.from_now
    )

    email = "agent-#{SecureRandom.hex(4)}@example.com"

    untenanted do
      assert_difference [ -> { Identity.count }, -> { User.count }, -> { Identity::AccessToken.count } ], +1 do
        post agent_bootstrap_claim_path(token: bootstrap.token),
          params: { email_address: email, name: "Board Agent", profile_name: "openclaw" },
          as: :json
      end
    end

    assert_response :created
    bootstrap.reload
    identity = Identity.find_by!(email_address: email)
    user = identity.users.find_by!(account: bootstrap.account)

    assert bootstrap.claimed?
    assert_equal identity, bootstrap.claimed_by_identity
    assert_equal "watching", bootstrap.board.access_for(user).involvement
    assert_equal bootstrap.account.slug, @response.parsed_body.dig("account", "slug")
    assert_equal bootstrap.board.id, @response.parsed_body.dig("board", "id")
    assert @response.parsed_body["token"].present?
  end

  test "claim reuses an existing user and access" do
    bootstrap = boards(:private).agent_bootstraps.create!(
      account: accounts("37s"),
      creator: users(:kevin),
      expires_at: 30.minutes.from_now
    )
    user = users(:jz)
    bootstrap.board.accesses.create!(user:, account: bootstrap.account, involvement: :access_only)

    untenanted do
      assert_no_difference [ -> { Identity.count }, -> { User.count } ] do
        assert_difference -> { user.identity.access_tokens.count }, +1 do
          post agent_bootstrap_claim_path(token: bootstrap.token),
            params: { email_address: user.identity.email_address, name: user.name },
            as: :json
        end
      end
    end

    assert_response :created
    assert_equal "watching", bootstrap.board.access_for(user).reload.involvement
  end

  test "claim returns gone for expired bootstrap" do
    bootstrap = boards(:writebook).agent_bootstraps.create!(
      account: accounts("37s"),
      creator: users(:kevin),
      expires_at: 1.minute.ago
    )

    untenanted do
      post agent_bootstrap_claim_path(token: bootstrap.token),
        params: { email_address: "expired@example.com", name: "Expired Agent" },
        as: :json
    end

    assert_response :gone
  end

  test "claim returns gone once already used" do
    bootstrap = boards(:writebook).agent_bootstraps.create!(
      account: accounts("37s"),
      creator: users(:kevin),
      expires_at: 30.minutes.from_now
    )

    untenanted do
      post agent_bootstrap_claim_path(token: bootstrap.token),
        params: { email_address: "used@example.com", name: "Used Agent" },
        as: :json
      assert_response :created

      post agent_bootstrap_claim_path(token: bootstrap.token),
        params: { email_address: "used-again@example.com", name: "Used Again" },
        as: :json
    end

    assert_response :gone
  end
end
