require "application_system_test_case"

class MermaidDiagramTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  setup do
    @card = cards(:layout)
    @comment = comments(:layout_overflowing_david)
    sign_in_as(users(:david))
  end

  test "a mermaid code block is drawn as a diagram" do
    @comment.update! body: mermaid_block("graph TD\n  Write --> Ship")

    visit card_url(@card)

    within_comment do
      assert_selector ".mermaid-diagram svg text", text: "Ship"
      assert_no_selector "pre", visible: :all
    end
  end

  test "a mermaid code block that does not parse shows its source" do
    @comment.update! body: mermaid_block("graph TD\n  Write -->")

    visit card_url(@card)

    within_comment do
      assert_selector "pre", text: "Write -->"
      assert_no_selector ".mermaid-diagram"
    end
  end

  test "a directive cannot turn on HTML labels" do
    @comment.update! body: mermaid_block(<<~MERMAID)
      %%{init: {"htmlLabels": true, "flowchart": {"htmlLabels": true}}}%%
      graph TD
        Write["<b class='planted' data-controller='planted'>Write</b>"] --> Ship
    MERMAID

    visit card_url(@card)

    within_comment do
      assert_selector ".mermaid-diagram svg text", text: "Ship"
      assert_no_selector "foreignObject, .planted, [data-controller=planted]", visible: :all
    end
  end

  test "a directive with a malformed theme colour does not break the diagrams after it" do
    @comment.update! body: mermaid_block(<<~MERMAID) + mermaid_block("graph TD\n  Write --> Ship")
      %%{init: {"theme": "dark", "themeVariables": {"mainBkg": "}"}}}%%
      graph TD
        Poison --> Pill
    MERMAID

    visit card_url(@card)

    within_comment do
      assert_selector ".mermaid-diagram svg text", text: "Pill"
      assert_selector ".mermaid-diagram svg text", text: "Ship"
    end
  end

  test "a directive cannot add CSS through the font family" do
    @comment.update! body: mermaid_block(<<~MERMAID)
      %%{init: {"fontFamily": "serif; & .planted { display: none }"}}%%
      graph TD
        Write --> Ship
    MERMAID

    visit card_url(@card)

    within_comment do
      assert_selector ".mermaid-diagram svg text", text: "Ship"
      assert_no_match(/planted/, find(".mermaid-diagram__inline svg")["outerHTML"])
    end
  end

  test "a directive cannot add CSS through a nested theme variable" do
    @comment.update! body: mermaid_block(<<~MERMAID)
      %%{init: {"themeVariables": {"radar": {"axisColor": "red; } .planted { display: none } .x { color: red"}}}}%%
      radar-beta
        axis A, B, C
        curve Ship{1, 2, 3}
    MERMAID

    visit card_url(@card)

    within_comment do
      assert_selector ".mermaid-diagram svg text", text: "Ship"
      assert_no_match(/planted/, find(".mermaid-diagram__inline svg")["outerHTML"])
    end
  end

  test "a drawn diagram has no data attributes" do
    @comment.update! body: mermaid_block("graph TD\n  Write --> Ship")

    visit card_url(@card)

    within_comment do
      assert_selector ".mermaid-diagram svg text", text: "Ship"
      assert_no_selector ".mermaid-diagram [data-id], .mermaid-diagram [data-look]", visible: :all
    end
  end

  test "a diagram does not load images from other sites" do
    @comment.update! body: mermaid_block(<<~MERMAID)
      flowchart TD
        Photo@{ img: "https://example.com/photo.png", label: "Photo" }
    MERMAID

    visit card_url(@card)

    within_comment do
      assert_selector ".mermaid-diagram svg text", text: "Photo"
      assert_no_selector ".mermaid-diagram svg image", visible: :all
    end
  end

  test "on a phone, a wide flowchart is laid out top to bottom, and left to right when expanded" do
    @comment.update! body: mermaid_block("flowchart LR\n  " + (1..6).map { "Step#{it}" }.join(" --> "))

    with_window_resized_to(390, 844) do
      visit card_url(@card)

      within_comment do
        assert_selector ".mermaid-diagram__inline svg text", text: "Step6"
        inline_width, inline_height = view_box_size_of(".mermaid-diagram__inline svg")
        expanded_width, expanded_height = view_box_size_of(".mermaid-diagram__expanded svg")

        assert_operator inline_height, :>, inline_width
        assert_operator expanded_width, :>, expanded_height
      end
    end
  end

  test "a drawn journey diagram has no HTML labels" do
    @comment.update! body: mermaid_block("journey\n  title Ship it\n  section Build\n    Write: 5: Me")

    visit card_url(@card)

    within_comment do
      assert_selector ".mermaid-diagram svg", visible: :all
      assert_no_selector ".mermaid-diagram foreignObject", visible: :all
    end
  end

  test "diagram SVG loses HTML labels and data attributes" do
    visit card_url(@card)

    clean = sanitize_diagram_svg \
      %(<svg xmlns="http://www.w3.org/2000/svg"><g class="node" data-action="click->planted#run"><foreignObject width="120" height="24">) +
      %(<div xmlns="http://www.w3.org/1999/xhtml"><a class="planted" data-controller="planted" href="https://evil.example">more</a>) +
      %(<form action="https://evil.example"><input name="password"></form></div></foreignObject></g></svg>)

    assert_no_match(/foreignObject|<a |<form|<input|data-|planted/, clean)
  end

  test "the expand button opens the diagram in a dialog" do
    @comment.update! body: mermaid_block("graph TD\n  Write --> Ship")

    visit card_url(@card)
    within_comment { click_on "Expand diagram" }

    assert_selector "dialog[open] svg text", text: "Ship"
    assert_selector ".mermaid-diagram[style*='--diagram-width:'][style*='--diagram-height:']"

    send_keys :escape

    assert_no_selector "dialog[open]"
  end

  test "the dialog shows a wide diagram at its natural size and scrolls" do
    @comment.update! body: mermaid_block("graph LR\n  " + (1..30).map { |n| "Node#{n}" }.join(" --> "))

    visit card_url(@card)
    # The wide inline diagram sits under the comment's hover controls, which intercept a real click.
    within_comment { find(".mermaid-diagram__expand").execute_script("this.click()") }

    assert_selector "dialog[open] svg text", text: "Node30"
    natural_width, shown_width, scrolls = page.evaluate_script(<<~JS)
      (() => {
        const container = document.querySelector("dialog[open] .mermaid-diagram__expanded")
        const svg = container.querySelector("svg")
        return [ svg.viewBox.baseVal.width, svg.getBoundingClientRect().width, container.scrollWidth > container.clientWidth ]
      })()
    JS
    assert_in_delta natural_width, shown_width, 1
    assert scrolls
  end

  test "the dialog fits a small diagram to the screen" do
    @comment.update! body: mermaid_block("info")

    visit card_url(@card)
    within_comment { click_on "Expand diagram" }

    assert_selector "dialog[open] svg", visible: :all
    assert_operator page.evaluate_script("document.querySelector('dialog[open] svg').getBoundingClientRect().width"), :>, 100
  end

  test "a broadcast refresh keeps the diagram in a card description" do
    @card.update! description: mermaid_block("graph TD\n  Write --> Ship")

    visit card_url(@card)
    assert_selector ".card__description .mermaid-diagram svg text", text: "Ship"

    wait_for_cable_subscriptions
    Current.user = users(:kevin)
    @card.update! title: "Retitled elsewhere"
    perform_enqueued_jobs only: Turbo::Streams::BroadcastStreamJob

    assert_selector "h1", text: "Retitled elsewhere", wait: 5
    assert_selector ".card__description .mermaid-diagram svg text", text: "Ship"
  end

  test "a page refresh keeps the diagram in a public card description" do
    @card.board.publish
    @card.update! description: mermaid_block("graph TD\n  Write --> Ship")

    visit public_board_card_url(@card.board.publication.key, @card)
    assert_selector ".card__description .mermaid-diagram svg text", text: "Ship"

    page.execute_script("document.querySelector('.mermaid-diagram').dataset.drawnBeforeRefresh = ''")
    page.execute_script("Turbo.visit(location.href, { action: 'replace' })")

    assert_selector ".card__description .mermaid-diagram:not([data-drawn-before-refresh]) svg text", text: "Ship"
  end

  test "a diagram drawn for source that a refresh has since changed is discarded" do
    @card.update! description: mermaid_block("graph TD\n  Write --> Ship")
    visit card_url(@card)
    assert_selector ".card__description .mermaid-diagram svg text", text: "Ship"
    hold_diagram_drawing
    wait_for_cable_subscriptions

    update_description_elsewhere "graph TD\n  Write --> Review"
    assert_selector ".card__description pre", text: "Review", visible: :all
    update_description_elsewhere "graph TD\n  Write --> Merge"
    assert_selector ".card__description pre", text: "Merge", visible: :all
    release_diagram_drawing

    assert_selector ".card__description .mermaid-diagram svg text", text: "Merge"
    assert_no_selector ".card__description .mermaid-diagram svg text", text: "Review"
  end

  test "a diagram drawn for a block whose language a refresh has since changed is discarded" do
    @card.update! description: mermaid_block("graph TD\n  Write --> Ship")
    visit card_url(@card)
    assert_selector ".card__description .mermaid-diagram svg text", text: "Ship"
    hold_diagram_drawing
    wait_for_cable_subscriptions

    update_description_elsewhere "graph TD\n  Write --> Review"
    assert_selector ".card__description pre", text: "Review", visible: :all
    update_description_elsewhere "graph TD\n  Write --> Review", language: "plain"
    assert_selector ".card__description pre[data-language=plain]", text: "Review"
    release_diagram_drawing

    assert_selector ".card__description pre[data-language=plain]", text: "Review"
    assert_no_selector ".card__description .mermaid-diagram"
  end

  test "a code block's language can be set to mermaid in the editor" do
    visit card_url(@card)
    find("lexxy-editor").click
    paste_markdown("```\ngraph TD\n  Write --> Ship\n```")

    find("lexxy-code-language-picker select").select "Mermaid"

    assert_selector "lexxy-editor code[data-language=mermaid] .code-token__attr", text: "graph"
  end

  test "the editor offers mermaid once after navigating back" do
    visit card_url(@card)
    find("lexxy-editor").click
    page.execute_script("Turbo.visit(arguments[0])", board_url(@card.board))
    assert_no_selector "lexxy-editor"

    page.go_back

    assert_selector "lexxy-code-language-picker select", visible: :all
    all("lexxy-code-language-picker select", visible: :all).each do |picker|
      within(picker) { assert_selector "option[value=mermaid]", count: 1, visible: :all }
    end
  end

  private
    def mermaid_block(source, language: "mermaid")
      %(<pre data-language="#{language}">#{ERB::Util.html_escape(source)}</pre>)
    end

    def sanitize_diagram_svg(svg)
      page.evaluate_async_script(<<~JS, svg)
        const [ svg, done ] = arguments
        import("helpers/mermaid_helpers").then(({ sanitizeDiagramSvg }) => done(sanitizeDiagramSvg(svg)))
      JS
    end

    def within_comment(&block)
      within "##{dom_id(@comment)}", &block
    end

    def view_box_size_of(selector)
      evaluate_script("(({ width, height }) => [ width, height ])(document.querySelector('#{selector}').viewBox.baseVal)")
    end

    def with_window_resized_to(width, height)
      window = Capybara.current_session.current_window
      original = window.size
      window.resize_to(width, height)
      yield
    ensure
      window.resize_to(*original)
    end

    def paste_markdown(markdown)
      page.execute_script(<<~JS, markdown)
        const dt = new DataTransfer();
        dt.setData("text/plain", arguments[0]);
        document.activeElement.dispatchEvent(new ClipboardEvent("paste", { clipboardData: dt, bubbles: true }));
      JS
    end

    def update_description_elsewhere(source, language: "mermaid")
      Current.user = users(:kevin)
      @card.update! description: mermaid_block(source, language: language)
      perform_enqueued_jobs only: Turbo::Streams::BroadcastStreamJob
    end

    # Each draw waits for the page's fonts before measuring labels, so holding that promise holds the draw.
    def hold_diagram_drawing
      page.execute_script(<<~JS)
        const fontsLoaded = new Promise(resolve => window.releaseDiagramDrawing = resolve)
        Object.defineProperty(document, "fonts", { configurable: true, value: { ready: fontsLoaded } })
      JS
    end

    # Resolves once the held draws and the controller's microtasks after them have run.
    def release_diagram_drawing
      page.evaluate_async_script(<<~JS)
        const [ done ] = arguments
        delete document.fonts
        window.releaseDiagramDrawing()
        setTimeout(done, 0)
      JS
    end

    # A broadcast sent before the page's subscriptions are confirmed is lost.
    def wait_for_cable_subscriptions
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
      assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all
    end
end
