class MoveEmailToIdentity < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :email_address, :string

    # Create identities for each unique email
    execute <<-SQL
      INSERT INTO identities (email_address, created_at, updated_at)
      SELECT DISTINCT email_address, datetime('now'), datetime('now')
      FROM memberships
      WHERE email_address IS NOT NULL
        AND email_address NOT IN (SELECT email_address FROM identities WHERE email_address IS NOT NULL);
    SQL

    # And link memberships to them
    execute <<-SQL
      UPDATE memberships
      SET identity_id = (
        SELECT id
        FROM identities
        WHERE identities.email_address = memberships.email_address
      )
      WHERE email_address IS NOT NULL;
    SQL

    # Delete memberships associated with identities without an email address
    execute <<-SQL
      DELETE FROM memberships
      WHERE identity_id IN (
        SELECT id
        FROM identities
        WHERE email_address IS NULL
      );
    SQL

    # Delete identities without an email address
    execute <<-SQL
      DELETE FROM identities
      WHERE email_address IS NULL;
    SQL

    change_column_null :memberships, :identity_id, false
    add_index :identities, :email_address, unique: true
    remove_column :memberships, :email_address
    remove_column :memberships, :user_id, :bigint
    rename_column :memberships, :user_tenant, :tenant
  end
end
