class MakeReactionsPolymorphic < ActiveRecord::Migration[8.0]
  def change
    add_column :reactions, :reactable_type, :string
    add_column :reactions, :reactable_id, :uuid

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE reactions SET reactable_type = 'Comment', reactable_id = comment_id
        SQL
      end

      dir.down do
        execute <<~SQL
          UPDATE reactions SET comment_id = reactable_id WHERE reactable_type = 'Comment'
        SQL
      end
    end

    change_column_null :reactions, :reactable_type, false
    change_column_null :reactions, :reactable_id, false

    remove_column :reactions, :comment_id, :uuid

    add_index :reactions, [:reactable_type, :reactable_id]
  end
end
