# This migration comes from fizzy_saas_engine (originally 20250924190529)
class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.timestamps
    end
  end
end
