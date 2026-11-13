require "test_helper"

class MermaidDiagramInteractionTest < RailsJsdom::TestCase
  setup do
    @card = cards(:layout)
    sign_in_as(users(:david))
  end

  test "a code block's language can be set to mermaid in the editor" do
    visit card_path(@card)
    find("lexxy-editor").click
    paste_markdown("```\ngraph TD\n  Write --> Ship\n```")

    within("lexxy-code-language-picker") { select "Mermaid" }

    assert_selector "lexxy-editor code[data-language=mermaid] .code-token__attr", text: "graph"
  end

  test "the editor offers mermaid once after navigating back" do
    visit card_path(@card)
    find("lexxy-editor").click
    execute_script("Turbo.visit(arguments[0])", board_path(@card.board))
    assert_no_selector "lexxy-editor"

    go_back

    assert_selector "lexxy-code-language-picker select", visible: :all
    all("lexxy-code-language-picker select", visible: :all).each do |picker|
      within(picker) { assert_selector "option[value=mermaid]", count: 1, visible: :all }
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
