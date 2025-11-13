require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  include SearchTestHelper

  setup do
    @board.update!(all_access: true)
    @card = @board.cards.create!(title: "Layout is broken", creator: @user)
    @comment_card = @board.cards.create!(title: "Some card", creator: @user)
    @comment_card.comments.create!(body: "overflowing text issue", creator: @user)

    untenanted { sign_in_as @user }
  end

  test "search" do
    # Searching by card title
    get search_path(q: "broken", script_name: "/#{@account.external_account_id}")
    assert_select "li", text: /Layout is broken/

    # Searching by comment
    get search_path(q: "overflowing", script_name: "/#{@account.external_account_id}")
    assert_select "li", text: /Some card/

    # Searching by card id
    get search_path(q: @card.id, script_name: "/#{@account.external_account_id}")
    assert_select "form[data-controller='auto-submit']"

    # Searching with non-existent card id
    get search_path(q: "999999", script_name: "/#{@account.external_account_id}")
    assert_select "form[data-controller='auto-submit']", count: 0
    assert_select ".search__empty", text: "No matches"
  end
end
