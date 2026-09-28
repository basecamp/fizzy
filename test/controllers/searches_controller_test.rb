require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  include SearchTestHelper

  setup do
    @board.update!(all_access: true)
    @card = @board.cards.create!(title: "Layout is broken", description: "Look at this mess.", status: "published", creator: @user)
    @comment_card = @board.cards.create!(title: "Some card", status: "published", creator: @user)
    @comment_card.comments.create!(body: "overflowing text issue", creator: @user)
    @comment2_card = @board.cards.create!(title: "Just haggis", description: "More haggis", status: "published", creator: @user)
    @comment2_card.comments.create!(body: "I love haggis", creator: @user)

    untenanted { sign_in_as @user }
  end

  test "search" do
    # Search query is blank: the landing state, not a search that found nothing
    get search_path(q: "", script_name: "/#{@account.external_account_id}")
    assert_response :success
    assert_select "h1.header__title", text: "Search"
    assert_select "li .search__title", count: 0
    assert_select ".search__blank-slate", count: 0

    # Searching by card title
    get search_path(q: "broken", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Layout is broken/
    assert_select "li .search__excerpt", text: /Look at this mess/

    # Searching by comment
    get search_path(q: "overflowing", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Some card/
    assert_select "li .search__excerpt--comment", text: /overflowing text issue/

    # Searching for a term that appears in a card and in a comment
    get search_path(q: "haggis", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Just haggis/, count: 2 # card title shows up in two entries
    assert_select "li .search__excerpt", text: /More haggis/ # one entry for the card description
    assert_select "li .search__excerpt--comment", text: /I love haggis/ # one entry for the comment
    assert_match(/<mark class="circled-text"><span><\/span>haggis<\/mark>/, response.body)

    # Searching by card number
    get search_path(q: @card.number, script_name: "/#{@account.external_account_id}")
    assert_select "form[data-controller='auto-submit']"

    # Searching by the number of a card the user cannot access
    get search_path(q: hidden_card.number, script_name: "/#{@account.external_account_id}")
    assert_select "form[data-controller='auto-submit']", count: 0
    assert_select ".search__blank-slate", text: "No matches"

    # Searching with non-existent card number
    get search_path(q: "999999", script_name: "/#{@account.external_account_id}")
    assert_select "form[data-controller='auto-submit']", count: 0
    assert_select ".search__blank-slate", text: "No matches"
  end

  test "search as JSON" do
    get search_path(q: "broken", script_name: "/#{@account.external_account_id}"), as: :json
    assert_response :success

    body = @response.parsed_body
    assert_kind_of Array, body
    assert_equal 1, body.size
    assert_equal "Layout is broken", body.first["title"]
  end

  test "search by card number as JSON returns array" do
    get search_path(q: @card.number, script_name: "/#{@account.external_account_id}"), as: :json
    assert_response :success

    body = @response.parsed_body
    assert_kind_of Array, body
    assert_equal 1, body.size
    assert_equal @card.id, body.first["id"]
  end

  test "search as JSON deduplicates cards with multiple search hits" do
    get search_path(q: "haggis", script_name: "/#{@account.external_account_id}"), as: :json
    assert_response :success

    body = @response.parsed_body
    assert_kind_of Array, body
    assert_equal 1, body.size
    assert_equal @comment2_card.id, body.first["id"]
  end

  test "search preserves highlight marks but escapes surrounding HTML" do
    @board.cards.create!(
      title: "<b>Bold</b> testing content",
      status: "published",
      creator: @user
    )

    get search_path(q: "testing", script_name: "/#{@account.external_account_id}")
    assert_response :success

    # Should escape <b> tags
    assert response.body.include?("&lt;b&gt;")
    # But should preserve highlight marks around "testing"
    assert_match(/<mark class="circled-text"><span><\/span>testing<\/mark>/, response.body)
  end

  test "an excerpt cut out of a longer description marks each end it cut" do
    filler = ([ "word" ] * 20).join(" ")
    @board.cards.create!(title: "Long winded", description: "#{filler} needle #{filler}",
      status: "published", creator: @user)

    get search_path(q: "needle", script_name: "/#{@account.external_account_id}")
    assert_response :success

    excerpt = search_result_excerpts.sole

    assert_includes excerpt, "needle", "control: no match in the excerpt leaves the ellipses proving nothing"
    assert excerpt.start_with?("..."), excerpt
    assert excerpt.end_with?("..."), excerpt
  end

  test "an excerpt reaching the end of a description marks only the end it cut" do
    @board.cards.create!(title: "Front loaded", description: "needle #{([ 'word' ] * 40).join(' ')}",
      status: "published", creator: @user)

    get search_path(q: "needle", script_name: "/#{@account.external_account_id}")
    assert_response :success

    excerpt = search_result_excerpts.sole

    assert_includes excerpt, "needle", "control: no match in the excerpt leaves the ellipses proving nothing"
    assert_not excerpt.start_with?("..."), excerpt
    assert excerpt.end_with?("..."), excerpt
  end

  test "search pages through more results than the default limit" do
    20.times { |i| @board.cards.create!(title: "paginated card #{i}", status: "published", creator: @user) }

    get search_path(q: "paginated", script_name: "/#{@account.external_account_id}")
    assert_response :success
    first_page = search_result_titles

    get search_path(q: "paginated", page: 2, script_name: "/#{@account.external_account_id}")
    assert_response :success
    second_page = search_result_titles

    assert_equal 15, first_page.size, "the first page should honour the 15-record ratio"
    assert_equal 5, second_page.size, "the second page should hold the remainder"
    assert_empty first_page & second_page, "pages should not repeat records"
  end

  test "the next-page link appears on the first page and not on the last" do
    20.times { |i| @board.cards.create!(title: "paginated card #{i}", status: "published", creator: @user) }

    get search_path(q: "paginated", script_name: "/#{@account.external_account_id}")
    assert_select "a#filtered_search_results-pagination-link-2", count: 1

    get search_path(q: "paginated", page: 2, script_name: "/#{@account.external_account_id}")
    assert_select "a#filtered_search_results-pagination-link-3", count: 0
  end

  test "a junk page param falls back to the first page" do
    20.times { |i| @board.cards.create!(title: "paginated card #{i}", status: "published", creator: @user) }

    %w[ 0 -1 abc ].each do |junk|
      get search_path(q: "paginated", page: junk, script_name: "/#{@account.external_account_id}")

      assert_response :success
      assert_equal 15, search_result_titles.size, "page=#{junk} should render the first page"
    end
  end

  test "a page past the store's result window renders instead of raising" do
    get search_path(q: "haggis", page: 5000, script_name: "/#{@account.external_account_id}")

    assert_response :success
  end

  test "MAX_SEARCH_PAGE is the last page the store's result window allows" do
    window = ActiveSearch.index(:searchable).store.capabilities.max_result_window
    relation = ActiveSearch.index(:searchable).search("haggis")

    last = relation.page(SearchesController::MAX_SEARCH_PAGE, per_page: SearchesController::SEARCH_PAGE_SIZES)
    assert_operator last.offset + last.limit, :<=, window

    assert_raises ActiveSearch::ResultWindowExceeded do
      relation.page(SearchesController::MAX_SEARCH_PAGE + 1, per_page: SearchesController::SEARCH_PAGE_SIZES)
    end
  end

  test "search with CJK content" do
    skip "MySQL fulltext requires tokens of 3+ characters" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    @board.cards.create!(title: "中文测试卡片", description: "这是中文描述", status: "published", creator: @user)
    @board.cards.create!(title: "日本語テスト", description: "日本語の説明", status: "published", creator: @user)
    @board.cards.create!(title: "한국어 테스트", description: "한국어 설명", status: "published", creator: @user)
    @board.cards.create!(title: "Mixed 混合 content", description: "English and 中文 together", status: "published", creator: @user)

    # Chinese search
    get search_path(q: "中文", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /中文测试卡片/
    assert_match(/<mark class="circled-text"><span><\/span>中文<\/mark>/, response.body)

    # Japanese search
    get search_path(q: "日本語", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /日本語テスト/

    # Korean search
    get search_path(q: "한국어", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /한국어 테스트/

    # Mixed CJK/English search
    get search_path(q: "混合", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Mixed 混合 content/
  end

  test "search with accented characters" do
    @board.cards.create!(title: "Hälsa och friskvård", description: "Möte i Göteborg", status: "published", creator: @user)

    # Accented characters must survive query sanitization
    get search_path(q: "hälsa", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Hälsa och friskvård/
    assert_match(/<mark class="circled-text"><span><\/span>Hälsa<\/mark>/, response.body)

    get search_path(q: "Göteborg", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__excerpt", text: /Möte i Göteborg/

    # Decomposed form (a + combining diaeresis) must survive sanitization and still match
    get search_path(q: "ha\u0308lsa", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Hälsa och friskvård/
  end

  private
    def search_result_titles
      css_select("li .search__title").map { |element| element.text.strip }
    end

    def search_result_excerpts
      css_select("li .search__excerpt:not(.search__excerpt--comment)")
        .map { |element| element.inner_html.gsub(/\s+/, " ").strip }
    end

    def hidden_card
      hidden_board = Board.create!(name: "Hidden Board", account: @account, creator: @user)
      hidden_board.accesses.revoke_from(@user)
      hidden_board.cards.create!(title: "Hidden card", status: "published", creator: @user)
    end
end
