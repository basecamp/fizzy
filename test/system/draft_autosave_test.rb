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

    # Capture the autosave request so we can await it (and any response it renders) before
    # asserting, rather than racing a timer.
    page.execute_script(<<~JS)
      window.__originalFetch = window.fetch
      window.__cardSave = null
      window.fetch = (...args) => {
        const promise = window.__originalFetch(...args)
        if (String(args[0]).includes("/cards/")) window.__cardSave = promise
        return promise
      }
    JS

    # Fire an autosave that captures "abc", then — before the response lands — append "def",
    # as the user would by continuing to type through the round-trip. submitForm reads the
    # FormData ("abc") synchronously before it awaits, so "def" lives only in the browser. A
    # Turbo Stream autosave morphs the card container (the draft's own editing form) and
    # resets the field to "abc", dropping "def".
    page.execute_script(<<~JS)
      const input = document.getElementById("card_title")
      input.focus()
      input.value = "abc"
      input.dispatchEvent(new Event("input", { bubbles: true }))     // schedules the autosave
      input.dispatchEvent(new FocusEvent("blur", { bubbles: true })) // fires it now; reads "abc"
      input.value = "abcdef"                                         // in-flight keystrokes
    JS

    # Barrier: wait for the save's response, then for two animation frames so request.js has
    # finished applying any Turbo Stream it carried (a morph would land in the microtasks
    # that drain before the next frame). Restore fetch. No fixed sleep, no timer race.
    page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      Promise.resolve(window.__cardSave)
        .then(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))))
        .then(() => { window.fetch = window.__originalFetch; done() })
    JS

    assert_equal "abc", card.reload.title,
      "expected the autosave to persist the value read when the request was sent"
    assert_equal "abcdef", find("#card_title").value,
      "autosave clobbered keystrokes typed while the save was in flight"
  end
end
