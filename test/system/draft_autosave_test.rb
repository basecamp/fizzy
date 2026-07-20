require "application_system_test_case"

class DraftAutosaveTest < ApplicationSystemTestCase
  # Regression for BC-10091763201 / BC-10036823881: a drafted card's background autosave
  # must persist without re-rendering the editing form, so keystrokes typed while a save
  # is in flight are never clobbered by the server's (one-round-trip-stale) echo.
  test "autosave does not drop keystrokes typed while a save is in flight" do
    sign_in_as(users(:david))

    board = boards(:writebook)
    visit board_url(board)
    click_on "Add a card"
    assert_selector "#card_title"

    card = board.cards.drafted.order(:created_at).last

    # Flag when the autosave request resolves, so we can assert only after the response
    # (and any re-render it drives) has been processed by the browser.
    page.execute_script(<<~JS)
      window.__autosaveComplete = false
      const originalFetch = window.fetch
      window.fetch = async (...args) => {
        const response = await originalFetch(...args)
        if (String(args[0]).includes("/cards/")) window.__autosaveComplete = true
        return response
      }
    JS

    # Fire an autosave that captures "abc", then — before the response can land — append
    # "def", as the user would by continuing to type through the round-trip. submitForm
    # reads the FormData ("abc") synchronously before it awaits, so "def" lives only in
    # the browser. A Turbo Stream autosave morphs the card container (the draft's own
    # editing form) and resets the field to "abc", dropping "def".
    page.execute_script(<<~JS)
      const input = document.getElementById("card_title")
      input.focus()
      input.value = "abc"
      input.dispatchEvent(new Event("input", { bubbles: true }))     // schedules the autosave
      input.dispatchEvent(new FocusEvent("blur", { bubbles: true })) // fires it now; reads "abc"
      input.value = "abcdef"                                         // in-flight keystrokes
    JS

    wait_until { page.evaluate_script("window.__autosaveComplete") }
    sleep 0.2 # let the browser apply any Turbo Stream from the response before asserting

    assert_equal "abc", card.reload.title,
      "expected the autosave to persist the value read when the request was sent"
    assert_equal "abcdef", find("#card_title").value,
      "autosave clobbered keystrokes typed while the save was in flight"
  end

  private
    def wait_until(timeout: Capybara.default_max_wait_time)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      until yield
        flunk "condition not met within #{timeout}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.05
      end
    end
end
