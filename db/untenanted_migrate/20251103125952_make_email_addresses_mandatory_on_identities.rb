class MakeEmailAddressesMandatoryOnIdentities < ActiveRecord::Migration[8.2]
  def change
    change_column_null :identities, :email_address, false
  end
end
