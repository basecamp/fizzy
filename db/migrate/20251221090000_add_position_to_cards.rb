class AddPositionToCards < ActiveRecord::Migration[8.2]
  STEP = 1024

  def up
    add_column :cards, :position, :bigint

    add_index :cards, [ :board_id, :column_id, :position ], name: "index_cards_on_board_id_and_column_id_and_position"
    add_index :cards, [ :board_id, :position ], name: "index_cards_on_board_id_and_position"

    backfill_positions
  end

  def down
    remove_index :cards, name: "index_cards_on_board_id_and_column_id_and_position"
    remove_index :cards, name: "index_cards_on_board_id_and_position"

    remove_column :cards, :position
  end

  private
    def backfill_positions
      board_ids = select_values("SELECT DISTINCT board_id FROM cards")

      board_ids.each do |board_id|
        backfill_stream_positions(board_id)
        backfill_column_positions(board_id)
        backfill_not_now_positions(board_id)
        backfill_closed_positions(board_id)
      end
    end

    def backfill_stream_positions(board_id)
      # Matches prior ordering: awaiting_triage.latest.with_golden_first
      execute <<~SQL.squish
        UPDATE cards c
        JOIN (
          SELECT c2.id,
                 (ROW_NUMBER() OVER (
                   ORDER BY (cg.id IS NULL) ASC, c2.last_active_at DESC, c2.id DESC
                 )) * #{STEP} AS new_position
          FROM cards c2
          LEFT JOIN card_goldnesses cg ON cg.card_id = c2.id
          LEFT JOIN card_not_nows cnn ON cnn.card_id = c2.id
          LEFT JOIN closures cl ON cl.card_id = c2.id
          WHERE c2.board_id = #{quote(board_id)}
            AND c2.status = 'published'
            AND c2.column_id IS NULL
            AND cnn.id IS NULL
            AND cl.id IS NULL
        ) ranked ON ranked.id = c.id
        SET c.position = ranked.new_position
        WHERE c.board_id = #{quote(board_id)}
          AND c.column_id IS NULL
      SQL
    end

    def backfill_column_positions(board_id)
      column_ids = select_values <<~SQL.squish
        SELECT DISTINCT column_id
        FROM cards
        WHERE board_id = #{quote(board_id)} AND column_id IS NOT NULL
      SQL

      column_ids.each do |column_id|
        # Matches prior ordering: active.latest.with_golden_first (within a column)
        execute <<~SQL.squish
          UPDATE cards c
          JOIN (
            SELECT c2.id,
                   (ROW_NUMBER() OVER (
                     ORDER BY (cg.id IS NULL) ASC, c2.last_active_at DESC, c2.id DESC
                   )) * #{STEP} AS new_position
            FROM cards c2
            LEFT JOIN card_goldnesses cg ON cg.card_id = c2.id
            LEFT JOIN card_not_nows cnn ON cnn.card_id = c2.id
            LEFT JOIN closures cl ON cl.card_id = c2.id
            WHERE c2.board_id = #{quote(board_id)}
              AND c2.status = 'published'
              AND c2.column_id = #{quote(column_id)}
              AND cnn.id IS NULL
              AND cl.id IS NULL
          ) ranked ON ranked.id = c.id
          SET c.position = ranked.new_position
          WHERE c.board_id = #{quote(board_id)}
            AND c.column_id = #{quote(column_id)}
        SQL
      end
    end

    def backfill_not_now_positions(board_id)
      # Matches prior ordering: postponed.latest
      execute <<~SQL.squish
        UPDATE cards c
        JOIN (
          SELECT c2.id,
                 (ROW_NUMBER() OVER (
                   ORDER BY c2.last_active_at DESC, c2.id DESC
                 )) * #{STEP} AS new_position
          FROM cards c2
          JOIN card_not_nows cnn ON cnn.card_id = c2.id
          LEFT JOIN closures cl ON cl.card_id = c2.id
          WHERE c2.board_id = #{quote(board_id)}
            AND c2.status = 'published'
            AND cl.id IS NULL
        ) ranked ON ranked.id = c.id
        SET c.position = ranked.new_position
        WHERE c.board_id = #{quote(board_id)}
      SQL
    end

    def backfill_closed_positions(board_id)
      # Matches prior ordering: closed.recently_closed_first
      execute <<~SQL.squish
        UPDATE cards c
        JOIN (
          SELECT c2.id,
                 (ROW_NUMBER() OVER (
                   ORDER BY cl.created_at DESC, c2.id DESC
                 )) * #{STEP} AS new_position
          FROM cards c2
          JOIN closures cl ON cl.card_id = c2.id
          WHERE c2.board_id = #{quote(board_id)}
        ) ranked ON ranked.id = c.id
        SET c.position = ranked.new_position
        WHERE c.board_id = #{quote(board_id)}
      SQL
    end

    def select_values(sql)
      connection.select_values(sql)
    end
end
