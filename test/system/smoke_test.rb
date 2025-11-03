require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "create a card" do
    sign_in_as(users(:david))

    visit collection_url(collections(:writebook))
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

    assert_image_figure_attachment content_type: "image/jpeg", caption: "moon.jpg"

    click_on "Post this comment"

    assert_image_figure_attachment content_type: "image/jpeg", caption: "moon.jpg"
  end

  test "dismissing notifications" do
    sign_in_as(users(:david))

    notif = notifications(:logo_card_david_mention_by_jz)

    assert_selector "div##{dom_id(notif)}"

    within_window(open_new_window) { visit card_url(notif.card) }

    assert_no_selector "div##{dom_id(notif)}"
  end

  private
    def sign_in_as(user)
      visit session_transfer_url(user.identity.transfer_id, script_name: nil)
      click_on ApplicationRecord.with_tenant(user.tenant) { Account.sole.name }
      assert_selector "h1", text: "Activity"
    end

    def fill_in_lexxy(selector = "lexxy-editor", with:)
      editor_element = find(selector)
      editor_element.set with
      page.execute_script("arguments[0].value = '#{with}'", editor_element)
    end

    def assert_figure_attachment(content_type:, &block)
      figure = find("figure.attachment[data-content-type='#{content_type}']")
      within(figure, &block) if block_given?
    end

    def assert_image_figure_attachment(content_type: "image/png", caption:)
      assert_figure_attachment(content_type: content_type) do
        assert_selector "img[src*='/rails/active_storage']", wait: 10
        assert_selector "figcaption input[placeholder='#{caption}']", wait: 10
      end
    end
end
