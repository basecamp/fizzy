module User::Searcher
  extend ActiveSupport::Concern

  included do
    # Nothing writes these any more; kept so the rows still get cleaned up.
    has_many :search_queries, class_name: "Search::Query", dependent: :destroy
  end

  HIGHLIGHT_OPENING_MARK = "<mark class=\"circled-text\"><span></span>"
  HIGHLIGHT_CLOSING_MARK = "</mark>"
  HIGHLIGHT_MARKERS = [ HIGHLIGHT_OPENING_MARK, HIGHLIGHT_CLOSING_MARK ].freeze

  # Always a lazy relation, so callers can page it. An unusable query filters to no board.
  def search(terms)
    build_search_relation(terms)
      .highlight(
        title: { markers: HIGHLIGHT_MARKERS },
        content: { markers: HIGHLIGHT_MARKERS, snippet: { words: 20 } }
      )
      .sort(created_at: :desc)
  end

  # limit(nil) because callers paginate this themselves: Card.mentioning strips
  # :select and :order before merging, but not the configured default :limit.
  def search_relation(terms)
    build_search_relation(terms).limit(nil).to_native_query
  end

  private
    def build_search_relation(terms)
      query = Search::Query.wrap(terms)
      boards = query.valid? ? board_ids : []

      ActiveSearch.index(:searchable)
        .search(query.to_s)
        .filter(account_id: account_id, board_id: boards)
    end
end
