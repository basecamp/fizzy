class CreateSearchEmbeddings < ActiveRecord::Migration[7.1]
  def change
    # create_virtual_table :search_embeddings, :vec0, [
    #   "id INTEGER PRIMARY KEY",
    #   "record_type TEXT NOT NULL",
    #   "record_id INTEGER NOT NULL",
    #   "embedding FLOAT[1536] distance_metric=cosine"
    # ]

    # Above is the original migration. Once the sqlite 'vec0' module was removed from the codebase
    # in 38a7a144 (following the table removal in 875a298f), this migration became unrunnable. So to
    # make sure we can reconstruct the schema if necessary by running all the migrations, I'm
    # replacing it with this empty table.
    create_table :search_embeddings
  end
end
