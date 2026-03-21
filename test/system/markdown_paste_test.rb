require "application_system_test_case"

class MarkdownPasteTest < ApplicationSystemTestCase
  test "markdown paste adds block spacing" do
    sign_in_as(users(:david))

    visit card_url(cards(:layout))
    find("lexxy-editor").click
    paste_markdown("Hello\n\nWorld")

    within("lexxy-editor") do
      assert_selector "p", text: "Hello"
      assert_selector "p br", visible: :all
      assert_selector "p", text: "World"
    end
  end

  test "markdown paste preserves line breaks" do
    sign_in_as(users(:david))

    visit card_url(cards(:layout))
    find("lexxy-editor").click
    paste_markdown("Hello\nWorld")

    inner_html = find("lexxy-editor p", text: "Hello").native.property("innerHTML")
    children = Nokogiri::HTML5.fragment(inner_html).children
    assert_pattern do
      children => [
        { name: "span", inner_html: "Hello" },
        { name: "br" },
        { name: "span", inner_html: "World" }
      ]
    end
  end

  private
    def paste_markdown(markdown)
      page.execute_script(<<~JS, markdown)
        const dt = new DataTransfer();
        dt.setData("text/plain", arguments[0]);
        document.activeElement.dispatchEvent(new ClipboardEvent("paste", { clipboardData: dt, bubbles: true }));
      JS
    end
end
