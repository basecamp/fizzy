require "test_helper"

class AgentBootstrapSkillsControllerTest < ActionDispatch::IntegrationTest
  test "show returns the skill for an active bootstrap" do
    bootstrap = boards(:writebook).agent_bootstraps.create!(
      account: accounts("37s"),
      creator: users(:kevin),
      expires_at: 30.minutes.from_now
    )

    untenanted do
      get agent_bootstrap_skill_path(token: bootstrap.token)
    end

    assert_response :success
    assert_equal "text/markdown; charset=utf-8", response.media_type + "; charset=#{response.charset}"
    assert_in_body "name: fizzy-cli"
    assert_in_body "fizzy auth bootstrap"
  end

  test "show returns gone for an expired bootstrap" do
    bootstrap = boards(:writebook).agent_bootstraps.create!(
      account: accounts("37s"),
      creator: users(:kevin),
      expires_at: 1.minute.ago
    )

    untenanted do
      get agent_bootstrap_skill_path(token: bootstrap.token)
    end

    assert_response :gone
  end

  test "show returns gone once a bootstrap has been claimed" do
    bootstrap = boards(:writebook).agent_bootstraps.create!(
      account: accounts("37s"),
      creator: users(:kevin),
      expires_at: 30.minutes.from_now,
      claimed_at: Time.current,
      claimed_by_identity: identities(:david)
    )

    untenanted do
      get agent_bootstrap_skill_path(token: bootstrap.token)
    end

    assert_response :gone
  end
end
