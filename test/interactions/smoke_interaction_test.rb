require "test_helper"

class SmokeInteractionTest < RailsJsdom::TestCase
  include ActionView::RecordIdentifier

  test "joining an account" do
    account = accounts("37s")

    visit join_path(code: account.join_code.code, script_name: account.slug)
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

    visit board_path(boards(:writebook))
    click_on "Add a card", match: :first
    fill_in "card_title", with: "Hello, world!"
    fill_in_lexxy with: "I am editing this thing"
    click_on "Create card"

    assert_selector "h3", text: "Hello, world!"
  end

  test "active storage attachments" do
    sign_in_as(users(:david))

    visit card_path(cards(:layout))
    fill_in_lexxy with: "Here is a comment"
    attach_file "Upload file", file_fixture("moon.jpg")

    within("form lexxy-editor figure.attachment[data-content-type='image/jpeg']") do
      assert_selector "img[src*='/rails/active_storage']"
      assert_selector "figcaption .attachment__caption-text", text: "moon.jpg"
    end

    click_on "Post"

    within("action-text-attachment") do
      assert_selector "a img[src*='/rails/active_storage']"
      assert_selector "figcaption span.attachment__name", text: "moon.jpg"
    end

    find("action-text-attachment figure.attachment a:has(img)").click

    assert_selector "dialog.lightbox[open]"
    within("dialog.lightbox") do
      assert_selector "img.lightbox__image[src*='/rails/active_storage']"
    end
  end

  test "lightbox shows the alt text of the image" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("moon.jpg").open, filename: "moon.jpg")
    cards(:layout).comments.create! \
      creator: users(:kevin),
      body: %(<action-text-attachment sgid="#{blob.attachable_sgid}" alt="A full moon"></action-text-attachment>)

    sign_in_as(users(:david))
    visit card_path(cards(:layout))
    find("action-text-attachment figure.attachment a:has(img)").click

    assert_selector "dialog.lightbox[open] img.lightbox__image[alt='A full moon']"
  end

  test "dismissing notifications" do
    sign_in_as(users(:david))
    visit root_path

    notification = notifications(:logo_mentioned_david)

    assert_selector "div##{dom_id(notification)}", visible: :all

    using_session(:other_window) do
      sign_in_as(users(:david))
      visit card_path(notification.card, script_name: notification.card.account.slug)
    end

    assert_no_selector "div##{dom_id(notification)}", visible: :all
  end

  private
    def fill_in_lexxy(selector = "lexxy-editor", with:)
      execute_script("document.querySelector(#{selector.to_json}).value = #{with.to_json}")
    end
end
