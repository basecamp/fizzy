class EnsureConsistentSchema < ActiveRecord::Migration[8.1]
  # ref: https://app.box-car.com/5986089/cards/2322
  def change
    change_column_default :accesses, :involvement, "access_only"

    unless index_exists?(:webhooks, :subscribed_actions)
      add_index :webhooks, :subscribed_actions
    end

    if index_exists?(:tags, [ :title ])
      remove_index :tags, [ :title ]
    end
    add_index :tags, [ :title ], unique: true
  end
end
