require "test_helper"

class ActiveSearch::StoreAdapters::MysqlShardedTest < ActiveSupport::TestCase
  OPENING_MARK = "<mark>"
  CLOSING_MARK = "</mark>"

  setup do
    @adapter = ActiveSearch::StoreAdapters::MysqlSharded.new
    @markers = [ OPENING_MARK, CLOSING_MARK ]
    @opts = field_options
  end

  test "stem single word" do
    result = @adapter.send(:stem, "running")

    assert_equal "run", result
  end

  test "stem multiple words" do
    result = @adapter.send(:stem, "test, running      JUMPING & walking")

    assert_equal "test run jump walk", result
  end

  test "stem splits on punctuation, as Search::Query does to the query side" do
    assert_equal "bc3 io 1d8b", @adapter.send(:stem, "BC3-IOS-1D8B")
    assert_equal "foo bar", @adapter.send(:stem, "foo---bar")
  end

  test "the shard comes from the routing value, not from anything held on the adapter" do
    index = ActiveSearch.index(:searchable)

    assert_equal "search_records_#{Zlib.crc32("abc") % 16}",
      @adapter.send(:model_for, index, routing: "abc").table_name
  end

  # Spelled out rather than derived from SHARD_COUNT: crc32("abc") % 8, % 16 and % 32 are all 2,
  # so a test that computes its own expectation cannot see the count move.
  test "routing spreads over search_records_0 to search_records_15 and nothing else" do
    index = ActiveSearch.index(:searchable)
    tables = 200.times.map { |value| @adapter.send(:model_for, index, routing: value.to_s).table_name }

    assert_equal (0..15).map { |shard| "search_records_#{shard}" }.sort, tables.uniq.sort
  end

  test "an index-wide question answers with the class every shard inherits" do
    assert_equal Search::Record, @adapter.send(:connection_model_for, ActiveSearch.index(:searchable))
  end

  test "no routing is an error rather than an arbitrary shard" do
    assert_raises(ArgumentError) { @adapter.send(:model_for, ActiveSearch.index(:searchable)) }
  end

  # Mysql answers false to both: this adapter marks matches itself, and User::Searcher
  # snippets content without snippetting title.
  INTENDED_CAPABILITY_DIFFERENCES = %i[ supports_highlighting? supports_highlight_per_field_snippets? ].freeze

  test "capabilities match Mysql's apart from the highlighting this adapter adds" do
    ours = @adapter.capabilities
    parent = ActiveSearch::StoreAdapters::Mysql.new.capabilities
    answered_alone = ActiveSearch::Capabilities.instance_methods(false).grep(/\?\z/).select do |predicate|
      ActiveSearch::Capabilities.instance_method(predicate).arity.zero?
    end

    INTENDED_CAPABILITY_DIFFERENCES.each do |predicate|
      assert_not_equal parent.public_send(predicate), ours.public_send(predicate), predicate
    end

    (answered_alone - INTENDED_CAPABILITY_DIFFERENCES).each do |predicate|
      assert_equal parent.public_send(predicate), ours.public_send(predicate), predicate
    end

    assert_equal parent.max_result_window, ours.max_result_window
  end

  test "a type column naming no constant at all is skipped" do
    assert_empty preload_sources(indexed_row("NoSuchModel", "1"))
  end

  test "a type column naming a constant that is not a model raises rather than dropping every highlight" do
    assert_raises(NoMethodError) { preload_sources(indexed_row("String", "1")) }
  end

  test "highlight simple word match" do
    result = @adapter.send(:highlight_text, "Hello world", "hello")

    assert_equal "#{mark('Hello')} world", result
  end

  test "highlight multiple occurrences" do
    result = @adapter.send(:highlight_text, "This is a test and another test", "test")

    assert_equal "This is a #{mark('test')} and another #{mark('test')}", result
  end

  test "highlight case insensitive" do
    result = @adapter.send(:highlight_text, "Ruby is great and RUBY rocks", "ruby")

    assert_equal "#{mark('Ruby')} is great and #{mark('RUBY')} rocks", result
  end

  test "highlight marks the words of a quoted phrase separately" do
    result = @adapter.send(:highlight_text, "Say hello world to everyone", '"hello world"')

    assert_equal "Say #{mark('hello')} #{mark('world')} to everyone", result
  end

  test "highlight marks a word the stemmer matched but the reader did not type" do
    result = @adapter.send(:highlight_text, "Implement authentication now", "authenticate")

    assert_equal "Implement #{mark('authentication')} now", result
  end

  test "highlight preserves an accented query and word" do
    assert_equal "café", Search::Query.new(terms: "café").tap(&:valid?).terms

    result = @adapter.send(:highlight_text, "a naive café here", "café")

    assert_equal "a naive #{mark('café')} here", result
  end

  test "highlight does not mark unrelated words sharing a prefix" do
    result = @adapter.send(:highlight_text, "Tricky text: don't stop", "don t")

    assert_equal "Tricky text: #{mark('don')}'#{mark('t')} stop", result
  end

  test "snippet returns full text with highlights when under max words" do
    result = @adapter.send(:highlight_snippet, "Ruby is great", "ruby", field_options(snippet: { words: 20 }))

    assert_equal "#{mark('Ruby')} is great", result
  end

  test "snippet creates excerpt around match" do
    text = "word " * 10 + "match " + "word " * 10
    result = @adapter.send(:highlight_snippet, text, "match", field_options(snippet: { words: 10 }))

    assert result.start_with?("...")
    assert result.end_with?("...")
    assert_includes result, mark("match")
  end

  test "snippet adds leading ellipsis when match is not at start" do
    text = "word " * 20 + "middle"
    result = @adapter.send(:highlight_snippet, text, "middle", field_options(snippet: { words: 10 }))

    assert result.start_with?("...")
    assert_not result.end_with?("...")
    assert_includes result, mark("middle")
  end

  test "snippet adds trailing ellipsis when text continues after excerpt" do
    text = "start " + "word " * 30
    result = @adapter.send(:highlight_snippet, text, "start", field_options(snippet: { words: 10 }))

    assert result.end_with?("...")
    assert_not result.start_with?("...")
    assert_includes result, mark("start")
  end

  test "snippet falls back to truncation when no match found" do
    text = "This text does not contain the search term " + "word " * 50
    result = @adapter.send(:highlight_snippet, text, "nomatch", field_options(snippet: { words: 10 }))

    assert_includes result, "..."
    assert_not_includes result, ActiveSearch::Highlighting::STORE_OPEN_MARKER
  end

  test "a fragment escapes HTML and preserves marks" do
    marked = @adapter.send(:highlight_text, "<script>test</script>", "test")

    assert_equal "&lt;script&gt;#{rendered('test')}&lt;/script&gt;",
      ActiveSearch::Highlighting.fragment(marked, @opts)
  end

  test "a fragment is nil when nothing was marked" do
    marked = @adapter.send(:highlight_text, "nothing here", "absent")

    assert_nil ActiveSearch::Highlighting.fragment(marked, @opts)
  end

  test "highlight leaves text alone when nothing matches" do
    result = @adapter.send(:highlight_text, "Hello world", "nomatch")

    assert_equal "Hello world", result
  end

  private
    IndexedRow = Struct.new(:searchable_type, :searchable_id)

    def indexed_row(type, id)
      IndexedRow.new(type, id)
    end

    def preload_sources(*rows)
      @adapter.send(:preload_highlight_sources, rows, ActiveSearch.index(:searchable))
    end

    def field_options(**options)
      ActiveSearch::Highlighting::FieldOptions.new(markers: @markers, **options)
    end

    # What the adapter writes: fragment swaps these for OPENING_MARK after escaping.
    def mark(text)
      "#{ActiveSearch::Highlighting::STORE_OPEN_MARKER}#{text}" \
        "#{ActiveSearch::Highlighting::STORE_CLOSE_MARKER}"
    end

    def rendered(text)
      "#{OPENING_MARK}#{text}#{CLOSING_MARK}"
    end
end
