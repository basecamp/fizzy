require "application_system_test_case"

class CommentSubmissionTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:david))
    visit card_url(cards(:layout))
    assert_selector "lexxy-editor[connected]"
    assert_button "Post", disabled: true
  end

  test "a single content update enables Post and clearing it disables Post" do
    replace_comment "A comment inserted without another keystroke"
    assert_button "Post", disabled: false

    replace_comment ""
    assert_button "Post", disabled: true

    replace_comment "Another comment"
    click_on "Post"
    assert_selector ".comment:not(.comment--new) .comment__body", text: "Another comment"
    assert_button "Post", disabled: true
  end

  test "a restored draft enables Post without typing" do
    replace_comment "A saved draft"
    assert_button "Post", disabled: false
    assert_local_draft "A saved draft"

    refresh
    assert_selector "lexxy-editor [contenteditable]", text: "A saved draft"
    assert_button "Post", disabled: false
  end

  test "the keyboard shortcut still posts a comment" do
    replace_comment "A comment sent with the keyboard"
    assert_button "Post", disabled: false

    find("lexxy-editor [contenteditable]").send_keys([ :control, :enter ])
    assert_selector ".comment:not(.comment--new) .comment__body", text: "A comment sent with the keyboard"
    assert_button "Post", disabled: true
  end

  private
    def replace_comment(text)
      # One editor update, as with a paste or dictation, without a following key.
      page.execute_script("document.querySelector('lexxy-editor').value = arguments[0]", text)
    end

    def assert_local_draft(text)
      assert_selector "form[data-local-save-key-value]"
      assert page.evaluate_async_script(<<~JS, text)
        const text = arguments[0]
        const done = arguments[arguments.length - 1]
        const key = document.querySelector("form[data-local-save-key-value]").dataset.localSaveKeyValue
        const deadline = Date.now() + 10000
        const check = () => {
          if (localStorage.getItem(key)?.includes(text)) done(true)
          else if (Date.now() >= deadline) done(false)
          else setTimeout(check, 50)
        }
        check()
      JS
    end
end
