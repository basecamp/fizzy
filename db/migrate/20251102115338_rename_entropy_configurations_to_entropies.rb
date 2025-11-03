class RenameEntropyConfigurationsToEntropies < ActiveRecord::Migration[8.2]
  def change
    rename_table :entropy_configurations, :entropies
  end
end
