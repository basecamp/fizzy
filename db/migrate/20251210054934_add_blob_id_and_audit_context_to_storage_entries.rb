class AddBlobIdAndAuditContextToStorageEntries < ActiveRecord::Migration[8.2]
  def change
    change_table :storage_entries do |t|
      t.references :blob, type: :uuid, foreign_key: false, index: true
      t.references :user, type: :uuid, foreign_key: false, index: true
      t.string :request_id, index: true
    end
  end
end
