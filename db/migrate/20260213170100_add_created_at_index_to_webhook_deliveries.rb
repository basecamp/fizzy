class AddCreatedAtIndexToWebhookDeliveries < ActiveRecord::Migration[8.2]
  def change
    add_index :webhook_deliveries, :created_at
  end
end
