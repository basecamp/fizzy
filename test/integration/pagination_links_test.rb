require "test_helper"

# A next-page link is built from the request's query string, so what a query says
# must only ever end up back in a query string. These tests render the pages that
# paginate, through real routing, because url_for reads its recalled route from the
# request and a helper test can't vouch for that. Search needs committed records,
# so its page is covered in SearchesControllerTest.
class PaginationLinksTest < ActionDispatch::IntegrationTest
  QUERIES_NAMING_URL_FOR_OPTIONS = [
    { use_route: "root" },
    { use_route: "card", id: "1" },
    { path_params: { format: "xml", board_id: "elsewhere" } }
  ]

  setup do
    @board = boards(:writebook)
    @board.publish
    @column = columns(:writebook_in_progress)
  end

  { "stream" => :stream, "column" => :column, "closed" => :closed, "not now" => :not_now }.each do |name, kind|
    test "public #{name} page's next-page link stays on its own route" do
      paginate kind

      assert_next_page_stays_on public_page(kind)
      QUERIES_NAMING_URL_FOR_OPTIONS.each { |query| assert_next_page_stays_on public_page(kind), **query }
    end

    test "board #{name} page's next-page link stays on its own route" do
      paginate kind
      sign_in_as :david

      assert_next_page_stays_on board_page(kind)
      QUERIES_NAMING_URL_FOR_OPTIONS.each { |query| assert_next_page_stays_on board_page(kind), **query }
    end
  end

  test "board page's stream next-page link stays on its own route" do
    paginate :stream
    sign_in_as :david

    [ {}, *QUERIES_NAMING_URL_FOR_OPTIONS ].each do |query|
      assert_next_page_stays_on board_path(@board), **query
      assert_select "a#maybe-pagination-link-2"
    end
  end

  test "board page's filtered next-page link stays on its own route and keeps the filter" do
    paginate :stream
    sign_in_as :david

    [ {}, *QUERIES_NAMING_URL_FOR_OPTIONS ].each do |query|
      assert_next_page_stays_on board_path(@board), creator_ids: [ users(:david).id ], **query
      assert_select "a#filtered_cards_paginated_container-pagination-link-2"
      assert_equal [ users(:david).id ], next_page_query["creator_ids"]
    end
  end

  test "cards page's next-page link stays on its own route and keeps the filter" do
    paginate :stream
    sign_in_as :david

    [ {}, *QUERIES_NAMING_URL_FOR_OPTIONS ].each do |query|
      assert_next_page_stays_on cards_path, creator_ids: [ users(:david).id ], sorted_by: "newest", **query
      assert_select "a#cards_paginated_container-pagination-link-2"
      assert_equal [ users(:david).id ], next_page_query["creator_ids"]
      assert_equal "newest", next_page_query["sorted_by"]
    end
  end

  test "the next-page link answers with the next page" do
    paginate :stream

    get public_page(:stream), params: { use_route: "root" }
    get next_page_href

    assert_response :success
    assert_select "a.pagination-link", count: 0
  end

  private
    def paginate(kind)
      Current.with(account: @board.account, session: sessions(:david)) do
        16.times do |index|
          card = @board.cards.create!(title: "Paginated #{index}", creator: users(:david), status: :published)

          case kind
          when :column then card.triage_into(@column)
          when :closed then card.close
          when :not_now then card.postpone
          end
        end
      end
    end

    def public_page(kind)
      key = @board.publication.key

      case kind
      when :stream then public_board_columns_stream_path(key)
      when :column then public_board_column_path(key, @column)
      when :closed then public_board_columns_closed_path(key)
      when :not_now then public_board_columns_not_now_path(key)
      end
    end

    def board_page(kind)
      case kind
      when :stream then board_columns_stream_path(@board)
      when :column then board_column_path(@board, @column)
      when :closed then board_columns_closed_path(@board)
      when :not_now then board_columns_not_now_path(@board)
      end
    end

    def assert_next_page_stays_on(path, **query)
      get path, params: query
      assert_response :success

      assert_equal path, URI(next_page_href).path
      assert_equal "2", next_page_query["page"]
    end

    def next_page_href
      css_select("a.pagination-link").first&.[]("href") || flunk("expected a next-page link")
    end

    def next_page_query
      Rack::Utils.parse_nested_query(URI(next_page_href).query)
    end
end
