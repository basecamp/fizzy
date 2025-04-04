class AddReasonToPops < ActiveRecord::Migration[8.1]
  def change
    add_column :pops, :reason, :string

    create_table :pop_reasons do |t|
      t.references :account, index: true
      t.string :label

      t.timestamps
    end
  end
end
