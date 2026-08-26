class AddTransferTokenGenerationToIdentities < ActiveRecord::Migration[8.2]
  def change
    add_column :identities, :transfer_token_generation, :bigint, null: false, default: 0
  end
end
