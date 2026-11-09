require "application_system_test_case"

class FilteredBoardColumnsTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  setup do
    sign_in_as(users(:david))
  end

  test "a card action that re-renders columns keeps them filtered" do
    triage = columns(:writebook_triage)
    visit board_url(boards(:writebook), tag_ids: [ tags(:mobile).id ], view: "columns")

    assert_selector "##{dom_id(triage)} .cards__expander-count", text: "1"
    assert_selector "#closed-cards .cards__expander-count", text: "0"
    assert_selector "##{dom_id(triage, :cards)} ##{dom_id(cards(:layout), :article)}", visible: :all

    close_card_like_a_hotkey cards(:layout)

    # Unfiltered, the closure's stream would show triage with 1 card and Done with 2.
    assert_selector "##{dom_id(triage)} .cards__expander-count", text: "0", wait: 5
    assert_selector "#closed-cards .cards__expander-count", text: "1"
    assert_current_path(/view=columns/)
  end

  test "moving a column keeps it filtered" do
    triage = columns(:writebook_triage)
    visit board_url(boards(:writebook), tag_ids: [ tags(:mobile).id ], view: "columns")
    assert_selector "##{dom_id(triage, :cards)} ##{dom_id(cards(:layout), :article)}", visible: :all

    page.execute_script("document.querySelector('##{dom_id(triage, :menu)} form[action$=\"right_position\"] button').click()")
    assert_selector "##{dom_id(columns(:writebook_in_progress))} ~ ##{dom_id(triage)}", visible: :all, wait: 5

    assert_selector "##{dom_id(triage, :cards)}[src*='tag_ids']", visible: :all, wait: 5
    assert_selector "##{dom_id(triage, :cards)} ##{dom_id(cards(:layout), :article)}", visible: :all
    assert_no_selector "##{dom_id(triage, :cards)} ##{dom_id(cards(:logo), :article)}", visible: :all
    assert_selector "##{dom_id(triage)} .cards__expander-count", text: "1"
  end

  private
    def close_card_like_a_hotkey(card)
      page.execute_script(<<~JS, dom_id(card, :article))
        const card = document.getElementById(arguments[0]).closest("[data-card-closure-url]")
        const token = document.querySelector("meta[name=csrf-token]")?.content ?? ""

        fetch(card.dataset.cardClosureUrl, { method: "POST", headers: { "Accept": "text/vnd.turbo-stream.html", "X-CSRF-Token": token } })
          .then(response => response.text())
          .then(html => Turbo.renderStreamMessage(html))
      JS
    end
end
