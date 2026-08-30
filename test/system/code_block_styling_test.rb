require "application_system_test_case"

class CodeBlockStylingTest < ApplicationSystemTestCase
  test "a code block and its nested code element share one background" do
    comments(:layout_overflowing_david).update! body: "<pre><code>puts :hello</code></pre>"

    sign_in_as(users(:david))
    visit card_url(cards(:layout))

    within "#comment_#{comments(:layout_overflowing_david).id}" do
      assert_equal background_color_of(find("pre")), background_color_of(find("pre code"))
    end
  end

  test "inline code keeps its chip background" do
    comments(:layout_overflowing_david).update! body: "<p>Run <code>puts :hello</code> now.</p>"

    sign_in_as(users(:david))
    visit card_url(cards(:layout))
    force_light_theme

    within "#comment_#{comments(:layout_overflowing_david).id}" do
      assert_equal "oklch(1 0 0)", background_color_of(find("code"))
    end
  end

  private
    # Without an explicit theme the chip colour follows the browser's
    # prefers-color-scheme, so this asserts light-mode values on a dark desktop.
    def force_light_theme
      page.execute_script("document.documentElement.setAttribute('data-theme', 'light')")
    end

    def background_color_of(element)
      page.evaluate_script("getComputedStyle(arguments[0]).backgroundColor", element)
    end
end
