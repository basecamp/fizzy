class CreateGithubIntegrationDeliveries < ActiveRecord::Migration[8.2]
  def change
    create_table :github_integration_deliveries, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :github_integration_id, null: false

      t.string :event_type, null: false
      t.string :state, null: false

      # Request/response data
      t.json :request
      t.json :response

      t.timestamps

      t.index [:account_id]
      t.index [:github_integration_id]
      t.index [:created_at]
    end
  end
end
