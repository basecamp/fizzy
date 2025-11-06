class Search
  attr_reader :user, :query

  HIGHLIGHT_OPENING_MARK = "<mark class=\"circled-text\"><span></span>"
  HIGHLIGHT_CLOSING_MARK = "</mark>"

  def self.table_name_prefix
    "search_"
  end

  def initialize(user, query)
    @user = user
    @query = Query.wrap(query)
  end

  def results
    cards = user.accessible_cards.search(query)
      .select([
        "cards.id as card_id",
        "null as comment_id",
        "highlight(cards_search_index, 0, '#{HIGHLIGHT_OPENING_MARK}', '#{HIGHLIGHT_CLOSING_MARK}') AS card_title",
        "snippet(cards_search_index, 1, '#{HIGHLIGHT_OPENING_MARK}', '#{HIGHLIGHT_CLOSING_MARK}', '...', 20) AS card_description",
        "null as comment_body",
        "boards.name as board_name",
        "cards.creator_id",
        "cards.created_at",
        "bm25(cards_search_index, 10.0, 2.0) AS score"
      ].join(","))

    comments = user.accessible_comments.search(query)
      .select([
        "comments.card_id as card_id",
        "comments.id as comment_id",
        "cards.title AS card_title",
        "null AS card_description",
        "snippet(comments_search_index, 0, '#{HIGHLIGHT_OPENING_MARK}', '#{HIGHLIGHT_CLOSING_MARK}', '...', 20) AS comment_body",
        "boards.name as board_name",
        "comments.creator_id",
        "comments.created_at",
        "bm25(comments_search_index, 1.0) AS score"
      ].join(","))

    union_sql = "(#{cards.to_sql} UNION #{comments.to_sql}) as search_results"
    Search::Result.from(union_sql).order(created_at: :desc)
  end
end
