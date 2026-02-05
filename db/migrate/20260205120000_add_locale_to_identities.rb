# frozen_string_literal: true

class AddLocaleToIdentities < ActiveRecord::Migration[8.2]
  def change
    add_column :identities, :locale, :string, limit: 10
  end
end
