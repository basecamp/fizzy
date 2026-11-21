require "test_helper"

class MarkdownPasteInteractionTest < RailsJsdom::TestCase
  test "markdown paste adds block spacing" do
    sign_in_as(users(:david))

    visit card_path(cards(:layout))
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

    visit card_path(cards(:layout))
    find("lexxy-editor").click
    paste_markdown("Hello\nWorld")

    inner_html = find("lexxy-editor p", text: "Hello").evaluate_script("this.innerHTML")
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
      execute_script(<<~JS, markdown)
        const dt = new DataTransfer();
        dt.setData("text/plain", arguments[0]);
        document.activeElement.dispatchEvent(new ClipboardEvent("paste", { clipboardData: dt, bubbles: true }));
      JS
    end
end
