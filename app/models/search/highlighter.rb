class Search::Highlighter
  OPENING_MARK = "<mark class=\"circled-text\"><span></span>"
  CLOSING_MARK = "</mark>"
  # Private-use characters mark matches during term passes, so a later term
  # can't match inside HTML inserted for an earlier one
  OPENING_SENTINEL = "\uE000"
  CLOSING_SENTINEL = "\uE001"
  ELIPSIS = "..."

  attr_reader :query

  def initialize(query)
    @query = query
  end

  def highlight(text)
    result = text.delete(OPENING_SENTINEL + CLOSING_SENTINEL)

    terms.each do |term|
      if term.match?(Search::CJK_PATTERN)
        result.gsub!(/(#{Regexp.escape(term)})/i) do |match|
          "#{OPENING_SENTINEL}#{match}#{CLOSING_SENTINEL}"
        end
      else
        result.gsub!(/(?<![a-zA-Z0-9_])(#{Regexp.escape(term)}[a-zA-Z0-9_]*)(?![a-zA-Z0-9_])/i) do |match|
          "#{OPENING_SENTINEL}#{match}#{CLOSING_SENTINEL}"
        end
      end
    end

    escape_highlight_marks(result)
  end

  def snippet(text, max_chars: 100)
    if text.length <= max_chars
      highlight(text)
    elsif (match_index = first_match_position(text))
      start_index = [ 0, match_index - max_chars / 2 ].max
      end_index = [ text.length, start_index + max_chars ].min

      snippet_text = text[start_index...end_index]
      snippet_text = "#{ELIPSIS}#{snippet_text}" if start_index > 0
      snippet_text = "#{snippet_text}#{ELIPSIS}" if end_index < text.length

      highlight(snippet_text)
    else
      "#{text[0, max_chars]}#{ELIPSIS}"
    end
  end

  private
    def terms
      @terms ||= begin
        terms = []

        query.scan(/"([^"]+)"/) do |phrase|
          terms << phrase.first
        end

        unquoted = query.gsub(/"[^"]+"/, "")
        unquoted.split(/\s+/).each do |word|
          next unless word.present?

          if word.match?(Search::CJK_PATTERN)
            terms << word
          else
            stemmed = Search::Stemmer.stem(word)
            terms << stemmed
            terms << word.downcase unless word.downcase.start_with?(stemmed)
          end
        end

        terms.uniq
      end
    end

    def first_match_position(text)
      terms.filter_map do |term|
        if term.match?(Search::CJK_PATTERN)
          text =~ /#{Regexp.escape(term)}/i
        else
          text =~ /(?<![a-zA-Z0-9_])#{Regexp.escape(term)}/i
        end
      end.min
    end

    def escape_highlight_marks(html)
      CGI.escapeHTML(html)
        .gsub(OPENING_SENTINEL, OPENING_MARK)
        .gsub(CLOSING_SENTINEL, CLOSING_MARK)
        .html_safe
    end
end
