class AssociateMagicLinksToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_reference :magic_links, :identity, foreign_key: true

    # Re-associate magic links from memberships to their identity
    execute <<-SQL
      UPDATE magic_links
      SET identity_id = (
        SELECT identity_id
        FROM memberships
        WHERE memberships.id = magic_links.membership_id
      )
      WHERE membership_id IS NOT NULL;
    SQL

    remove_column :magic_links, :membership_id
  end
end
