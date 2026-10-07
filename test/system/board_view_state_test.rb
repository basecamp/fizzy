require "application_system_test_case"

class BoardViewStateTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  setup do
    sign_in_as(users(:david))
    Current.session = sessions(:david)
    @board = boards(:writebook)
    @column = columns(:writebook_review)
    @cards = 35.times.map do |i|
      @board.cards.create!(title: "Return state card #{i + 1}", column: @column, status: :published, last_active_at: i.minutes.ago)
    end
  end

  test "Esc restores the expanded column and scroll beyond the first page" do
    visit board_url(@board)
    open_column
    load_second_page
    card = @cards[20]
    link = find("a", text: card.title, exact_text: true)
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", link)
    original_y = page.evaluate_script("window.scrollY")
    assert_operator original_y, :>, 0
    link.click
    assert_current_path card_path(card)

    send_keys :escape
    assert_current_path board_path(@board)
    assert_selector "##{dom_id(@column)}.is-expanded"
    assert_selector "##{dom_id(card, :article)}", visible: true
    assert_restored
    assert_in_delta original_y, page.evaluate_script("window.scrollY"), 5
  end

  test "browser Back restores mobile column scroll and horizontal position" do
    page.current_window.resize_to(390, 844)
    visit board_url(@board)
    open_column
    load_second_page
    card = @cards[20]
    link = find("a", text: card.title, exact_text: true)
    page.execute_script("arguments[0].scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' })", link)
    original_y = page.evaluate_script("document.querySelector('##{dom_id(@column)} .cards__list').scrollTop")
    original_x = page.evaluate_script("document.querySelector('.card-columns').scrollLeft")
    assert_operator original_y, :>, 0
    link.click
    assert_current_path card_path(card)

    page.go_back
    assert_current_path board_path(@board)
    assert_selector "##{dom_id(@column)}.is-expanded"
    assert_selector "##{dom_id(card, :article)}", visible: true
    assert_restored
    assert_in_delta original_y, page.evaluate_script("document.querySelector('##{dom_id(@column)} .cards__list').scrollTop"), 5
    assert_in_delta original_x, page.evaluate_script("document.querySelector('.card-columns').scrollLeft"), 5
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private
    def assert_restored
      assert_selector ".card-columns" do
        page.evaluate_script("window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('.card-columns'), 'board-view').restored")
      end
    end

    def open_column
      within("##{dom_id(@column)}") { find("button.cards__expander").click }
      assert_selector "##{dom_id(@column)}.is-expanded"
    end

    def load_second_page
      within("##{dom_id(@column)}") do
        assert_selector "a", text: @cards.first.title
        page.execute_script("const link = document.querySelector('##{dom_id(@column)} [data-pagination-target=\"paginationLink\"]'); const controller = window.Stimulus.getControllerForElementAndIdentifier(link.closest('[data-controller~=pagination]'), 'pagination'); controller.loadPage({ target: link })")
        assert_selector "a", text: @cards[20].title, visible: :all
      end
    end
end
