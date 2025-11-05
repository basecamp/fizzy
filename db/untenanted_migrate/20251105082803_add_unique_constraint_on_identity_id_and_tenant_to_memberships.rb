class AddUniqueConstraintOnIdentityIdAndTenantToMemberships < ActiveRecord::Migration[8.2]
  def change
    # Remove duplicates, keeping the youngest membership for each identity_id + tenant combination
    execute <<-SQL
      DELETE FROM memberships
      WHERE id NOT IN (
        SELECT MAX(id)
        FROM memberships
        GROUP BY identity_id, tenant
      )
    SQL

    add_index :memberships, %i[ tenant identity_id ], unique: true
  end
end
