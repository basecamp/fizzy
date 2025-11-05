class RemoveEmailAddressAndPasswordDigestFromUsers < ActiveRecord::Migration[8.2]
  def change
    remove_column :users, :email_address, :string
    remove_column :users, :password_digest, :string
  end
end
