class CreateSearchEmbeddings < ActiveRecord::Migration[7.1]
  def change
    create_virtual_table :search_embeddings, :vec0, [
      "id INTEGER PRIMARY KEY",
      "record_type TEXT NOT NULL",
      "record_id INTEGER NOT NULL",
      "embedding FLOAT[1536] distance_metric=cosine"
    ]
  end
end
