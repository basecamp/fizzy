module AgentBootstrapsHelper
  def link_to_agent_bootstrap(board)
    link_to new_board_agent_bootstrap_path(board),
        class: "btn btn--circle-mobile",
        data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: "Agent setup" } do
      icon_tag("settings") + tag.span("Agent setup", class: "for-screen-reader")
    end
  end

  def agent_bootstrap_claim_url_for(agent_bootstrap)
    agent_bootstrap_claim_url(token: agent_bootstrap.token)
  end

  def agent_bootstrap_setup_command(agent_bootstrap)
    suggested_email = "agent+#{agent_bootstrap.board.id.first(8)}@example.com"
    suggested_name = "#{agent_bootstrap.board.name} Agent"

    %(fizzy auth bootstrap "#{agent_bootstrap_claim_url_for(agent_bootstrap)}" --email "#{suggested_email}" --name "#{suggested_name}")
  end
end
