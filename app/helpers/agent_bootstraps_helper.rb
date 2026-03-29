module AgentBootstrapsHelper
  require "shellwords"

  AGENT_BOOTSTRAP_SKILL_NAME = "fizzy-cli"

  def link_to_agent_bootstrap(board)
    link_to new_board_agent_bootstrap_path(board),
        class: "btn btn--circle-mobile",
        data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: "Agent setup" } do
      icon_tag("settings") + tag.span("Agent setup", class: "for-screen-reader")
    end
  end

  def agent_bootstrap_claim_url_for(agent_bootstrap)
    agent_bootstrap_claim_url(token: agent_bootstrap.token, script_name: nil)
  end

  def agent_bootstrap_skill_url_for(agent_bootstrap)
    agent_bootstrap_skill_url(token: agent_bootstrap.token, script_name: nil)
  end

  def agent_bootstrap_setup_command(agent_bootstrap)
    suggested_email = "agent+#{agent_bootstrap.token.to_s[0, 8]}@example.com"
    suggested_name = "#{agent_bootstrap.board.name} Agent"

    Shellwords.shelljoin([
      "fizzy", "auth", "bootstrap", agent_bootstrap_claim_url_for(agent_bootstrap),
      "--email", suggested_email,
      "--name", suggested_name
    ])
  end

  def agent_bootstrap_skill_name
    AGENT_BOOTSTRAP_SKILL_NAME
  end

  def agent_bootstrap_skill_block(agent_bootstrap)
    <<~TEXT.strip
      Download the Fizzy CLI skill from:
      #{agent_bootstrap_skill_url_for(agent_bootstrap)}

      Load that skill into your agent, then run:
      #{agent_bootstrap_setup_command(agent_bootstrap)}

      Verify the bootstrap with:
      fizzy whoami --json
    TEXT
  end
end
