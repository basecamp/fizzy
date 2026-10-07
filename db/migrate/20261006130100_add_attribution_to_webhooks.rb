class AddAttributionToWebhooks < ActiveRecord::Migration[8.2]
  def change
    add_reference :webhooks, :creator, type: :uuid, foreign_key: false
    add_reference :webhooks, :created_via, type: :uuid, foreign_key: false
  end
end
