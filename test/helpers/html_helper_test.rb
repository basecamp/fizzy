require "test_helper"

class HtmlHelperTest < ActionView::TestCase
  test "convert URLs into anchor tags" do
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com" rel="noopener noreferrer">https://example.com</a></p>),
      format_html("<p>Check this: https://example.com</p>")
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a></p>),
      format_html("<p>Check this: https://example.com/</p>")
  end

  test "convert multiple URLs in the same string" do
    assert_equal_html \
      %(Visit <a href="https://foo.com/" rel="noopener noreferrer">https://foo.com/</a>. Also see <a href="https://bar.com/" rel="noopener noreferrer">https://bar.com/</a>!),
      format_html("Visit https://foo.com/. Also see https://bar.com/!")
  end

  test "don't include punctuation in URL autolinking" do
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>!</p>),
      format_html("<p>Check this: https://example.com/!</p>")
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>.</p>),
      format_html("<p>Check this: https://example.com/.</p>")
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>?</p>),
      format_html("<p>Check this: https://example.com/?</p>")
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>,</p>),
      format_html("<p>Check this: https://example.com/,</p>")
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>:</p>),
      format_html("<p>Check this: https://example.com/:</p>")
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>;</p>),
      format_html("<p>Check this: https://example.com/;</p>")
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>"</p>),
      format_html("<p>Check this: https://example.com/\"</p>")
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>'</p>),
      format_html("<p>Check this: https://example.com/'</p>")

    # trailing entities that decode to punctuation
    # use assert_equal and not assert_equal_html to make sure we're getting entities correct
    assert_equal \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>&lt;</p>),
      format_html("<p>Check this: https://example.com/&lt;</p>")
    assert_equal \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>&gt;</p>),
      format_html("<p>Check this: https://example.com/&gt;</p>")
    assert_equal \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>"</p>),
      format_html("<p>Check this: https://example.com/&quot;</p>")

    # multiple punctuation characters including entities
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>!?;</p>),
      format_html("<p>Check this: https://example.com/!?;</p>")
    assert_equal_html \
      %(&lt;img src="<a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>"&gt;),
      format_html(%(&lt;img src=&quot;https://example.com/&quot;&gt;))
    assert_equal_html \
      %(&lt;img src="<a href="https://example.com/" rel="noopener noreferrer">https://example.com/</a>"!&gt;),
      format_html(%(&lt;img src=&quot;https://example.com/&quot;!&gt;))
  end

  test "make sure the linked content is properly sanitized" do
    # https://hackerone.com/reports/3481093
    result = format_html(%(https://google.com/\"&gt;test&lt;/a&gt;&lt;input&gt;&lt;/input&gt;))
    assert_no_match(/<input>/i, result, "should not create an input element")

    result = format_html(%(https://google.com/\"&gt;&lt;script&gt;alert('xss')&lt;/script&gt;))
    assert_no_match(/<script>/i, result, "should not create a script element")
  end

  test "handle URLs with query parameters" do
    # use assert_equal and not assert_equal_html to make sure we're getting entities correct
    assert_equal \
      %(<p>Check this: <a href="https://example.com/a?b=c&amp;d=e" rel="noopener noreferrer">https://example.com/a?b=c&amp;d=e</a></p>),
      format_html("<p>Check this: https://example.com/a?b=c&amp;d=e</p>")

    assert_equal \
      %(<p>Check this: <a href="https://example.com/a?b=c&amp;d=e" rel="noopener noreferrer">https://example.com/a?b=c&amp;d=e</a></p>),
      format_html("<p>Check this: https://example.com/a?b=c&d=e</p>")
  end

  test "respect existing links" do
    assert_equal_html \
      %(<p>Check this: <a href="https://example.com">https://example.com</a></p>),
      format_html("<p>Check this: <a href=\"https://example.com\">https://example.com</a></p>")
  end

  test "convert email addresses into mailto links" do
    assert_equal_html \
      %(<p>Contact us at <a href="mailto:support@example.com" rel="noopener noreferrer">support@example.com</a></p>),
      format_html("<p>Contact us at support@example.com</p>")
  end

  test "respect existing linked emails" do
    assert_equal_html \
      %(<p>Contact us at <a href="mailto:support@example.com">support@example.com</a></p>),
      format_html(%(<p>Contact us at <a href="mailto:support@example.com">support@example.com</a></p>))
  end

  test "don't autolink content in excluded elements" do
    %w[ figcaption pre code ].each do |element|
      assert_equal_html \
        "<#{element}>Check this: https://example.com</#{element}>",
        format_html("<#{element}>Check this: https://example.com</#{element}>")
    end
  end

  test "preserve escaped HTML containing URLs" do
    input = 'before text &lt;img src="https://example.com/image.png"&gt; after text'
    output = format_html(input)

    assert_no_match(/<img/, output, "should not create an img element")
    assert_includes output, "&lt;img"
  end

  test "card_html_title renders backticks as code elements" do
    assert_equal "Fix the <code>bug</code> in production", card_html_title(cards(:logo).tap { _1.title = "Fix the `bug` in production" })
  end

  test "card_html_title renders multiple code spans" do
    assert_equal "<code>foo</code> and <code>bar</code>", card_html_title(cards(:logo).tap { _1.title = "`foo` and `bar`" })
  end

  test "card_html_title renders code spans without surrounding spaces" do
    assert_equal "what<code>about</code>this", card_html_title(cards(:logo).tap { _1.title = "what`about`this" })
  end

  test "card_html_title escapes HTML tags" do
    assert_equal "&lt;script&gt;alert(1)&lt;/script&gt;", card_html_title(cards(:logo).tap { _1.title = "<script>alert(1)</script>" })
  end

  test "card_html_title escapes HTML inside backticks" do
    assert_equal "<code>&lt;script&gt;</code>", card_html_title(cards(:logo).tap { _1.title = "`<script>`" })
  end

  test "card_html_title returns blank title as-is" do
    assert_nil card_html_title(cards(:logo).tap { _1.title = nil })
    assert_equal "", card_html_title(cards(:logo).tap { _1.title = "" })
  end
end
