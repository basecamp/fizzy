class AddFailureReasonToAccountImports < ActiveRecord::Migration[8.2]
  def change
    add_column :account_imports, :failure_reason, :string
  end
end
