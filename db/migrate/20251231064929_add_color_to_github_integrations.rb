class AddColorToGithubIntegrations < ActiveRecord::Migration[8.2]
  def change
    add_column :github_integrations, :color, :string, default: "var(--color-card-7)"
  end
end
