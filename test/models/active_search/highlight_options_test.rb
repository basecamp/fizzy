require "test_helper"

class ActiveSearch::HighlightOptionsTest < ActiveSupport::TestCase
  include SearchTestHelper

  setup do
    body = (%w[ alpha bravo charlie delta echo foxtrot golf hotel india juliett kilo lima
      mike november oscar papa quebec romeo sierra tango uniform ] + [ "kestrel" ] +
      %w[ victor whiskey xray yankee zulu one two three four five six ]).join(" ")
    @card = @board.cards.create!(title: "plain title", status: "published",
                                 creator: @user, description: body)
  end

  def highlight(opts)
    ActiveSearch.index(:searchable).search("kestrel")
      .filter(account_id: @account.id, board_id: [ @board.id ])
      .highlight(content: opts).results.to_a.first&.hit&.highlight(:content)
  end

  test "a word snippet honours the size it was given" do
    assert_equal 5, highlight(snippet: { words: 5 }).to_s.split(/\s+/).size
    assert_equal 12, highlight(snippet: { words: 12 }).to_s.split(/\s+/).size
  end

  test "a field that matched nothing has no highlight, even with a snippet" do
    long = (1..60).map { |i| "word#{i}" }.join(" ")
    @board.cards.create!(title: "kestrel in the title", status: "published",
                         creator: @user, description: long)

    hit = ActiveSearch.index(:searchable).search("kestrel")
      .filter(account_id: @account.id, board_id: [ @board.id ])
      .highlight(title: true, content: { snippet: { words: 20 } })
      .results.to_a.find { |r| r.title == "kestrel in the title" }.hit

    assert_match "kestrel", hit.highlight(:title)
    assert_nil hit.highlight(:content)
  end

  test "title and content each honour their own snippet size" do
    short = (1..10).map { |i| "word#{i}" }.join(" ")
    long = (1..40).map { |i| "word#{i}" }.join(" ")
    @board.cards.create!(title: "#{short} peregrine #{short}", status: "published",
                         creator: @user, description: "#{long} peregrine #{long}")

    hit = ActiveSearch.index(:searchable).search("peregrine")
      .filter(account_id: @account.id, board_id: [ @board.id ])
      .highlight(title: { snippet: { words: 3 } }, content: { snippet: { words: 9 } })
      .results.to_a.first.hit

    assert_equal 3, hit.highlight(:title).to_s.split(/\s+/).size
    assert_equal 9, hit.highlight(:content).to_s.split(/\s+/).size
  end

  test "a text format is neither escaped nor marked html safe" do
    @card.update!(description: "Tom & Jerry kestrel tail")
    value = highlight(format: :text, markers: [ "[", "]" ])

    assert_equal "Tom & Jerry [kestrel] tail", value
    assert_not value.html_safe?
  end

  test "an html format escapes the text but not the markers" do
    @card.update!(description: "Tom & Jerry kestrel tail")
    value = highlight(format: :html, markers: [ "<em>", "</em>" ])

    assert_equal "Tom &amp; Jerry <em>kestrel</em> tail", value
    assert_predicate value, :html_safe?
  end
end
