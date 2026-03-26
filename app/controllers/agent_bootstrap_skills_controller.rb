class AgentBootstrapSkillsController < ApplicationController
  disallow_account_scope
  allow_unauthenticated_access

  def show
    bootstrap = Board::AgentBootstrap.find_by!(token: params.expect(:token))
    raise ActiveRecord::RecordNotFound unless bootstrap.claimable?

    send_data skill_source,
      filename: "fizzy-cli.SKILL.md",
      type: "text/markdown; charset=utf-8",
      disposition: "inline"
  rescue ActiveRecord::RecordNotFound
    head :gone
  end

  private
    def skill_source
      Rails.root.join("skills", "fizzy-cli", "SKILL.md").read
    end
end
