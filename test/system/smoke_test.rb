require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "joining an account" do
    account = accounts("37s")

    visit join_url(code: account.join_code.code, script_name: account.slug)
    fill_in "Email address", with: "newbie@example.com"
    click_on "Continue"

    assert_selector "h1", text: "Check your email"
    identity = Identity.find_by!(email_address: "newbie@example.com")
    code = identity.magic_links.active.first.code
    fill_in "code", with: code
    send_keys :enter

    assert_selector "input[id=user_name]"
    assert account.users.find_by!(identity:).verified?, "User was not properly verified"
    fill_in "Full name", with: "New Bee"
    click_on "Continue"

    assert_selector "h1", text: "Writebook"
  end

  test "create a card" do
    sign_in_as(users(:david))

    visit board_url(boards(:writebook))
    click_on "Add a card"
    fill_in "card_title", with: "Hello, world!"
    fill_in_lexxy with: "I am editing this thing"
    click_on "Create card"

    assert_selector "h3", text: "Hello, world!"
  end

  test "active storage attachments" do
    sign_in_as(users(:david))

    visit card_url(cards(:layout))
    fill_in_lexxy with: "Here is a comment"
    attach_file file_fixture("moon.jpg") do
      click_on "Upload file"
    end

    within("form lexxy-editor figure.attachment[data-content-type='image/jpeg']") do
      assert_selector "img[src*='/rails/active_storage']"
      assert_selector "figcaption textarea[placeholder='moon.jpg']"
    end

    click_on "Post"

    within("action-text-attachment") do
      assert_selector "a img[src*='/rails/active_storage']"
      assert_selector "figcaption span.attachment__name", text: "moon.jpg"
    end

    # Click the image to open the lightbox
    find("action-text-attachment figure.attachment a:has(img)").click

    assert_selector "dialog.lightbox[open]"
    within("dialog.lightbox") do
      assert_selector "img.lightbox__image[src*='/rails/active_storage']"
    end
  end

  test "dismissing notifications" do
    sign_in_as(users(:david))

    notification = notifications(:logo_mentioned_david)

    assert_selector "div##{dom_id(notification)}"

    within_window(open_new_window) { visit card_url(notification.card) }

    assert_no_selector "div##{dom_id(notification)}"
  end

  test "dragging card to a new column" do
    sign_in_as(users(:david))

    card = Card.find("03axhd1h3qgnsffqplkyf28fv")
    assert_nil(card.column)

    visit board_url(boards(:writebook))

    card_el = page.find("#article_card_03axhd1h3qgnsffqplkyf28fv")
    column_el = page.find("#column_03axmcferfmbnv4qg816nw6bg")
    cards_count = column_el.find(".cards__expander-count").text.to_i

    card_el.drag_to(column_el)

    column_el.find(".cards__expander-count", text: cards_count + 1)
    assert_equal("Triage", card.reload.column.name)
  end

  private
    def sign_in_as(user)
      visit session_transfer_url(user.identity.transfer_id, script_name: nil)
      assert_selector "h1", text: "Latest Activity"
    end

    def fill_in_lexxy(selector = "lexxy-editor", with:)
      editor_element = find(selector)
      editor_element.set with
      page.execute_script("arguments[0].value = '#{with}'", editor_element)
    end
end
