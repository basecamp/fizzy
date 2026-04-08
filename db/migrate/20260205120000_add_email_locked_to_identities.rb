# frozen_string_literal: true

class AddEmailLockedToIdentities < ActiveRecord::Migration[8.0]
  def change
    add_column :identities, :email_locked, :boolean, default: false, null: false
  end
end
