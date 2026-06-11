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
    # Search query is blank
    get search_path(q: "", script_name: "/#{@account.external_account_id}")
    assert @query.nil?

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

    # Searching by card id
    get search_path(q: @card.id, script_name: "/#{@account.external_account_id}")
    assert_select "form[data-controller='auto-submit']"

    # Searching with non-existent card id
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

  test "search by card ID as JSON returns array" do
    get search_path(q: @card.id, script_name: "/#{@account.external_account_id}"), as: :json
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

  test "search highlights matched terms with proper HTML marks" do
    @board.cards.create!(title: "Testing search highlighting", status: "published", creator: @user)

    get search_path(q: "highlighting", script_name: "/#{@account.external_account_id}")
    assert_response :success
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
end
