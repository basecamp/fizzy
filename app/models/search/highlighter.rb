require "mittens"

# Produces the store markers that ActiveSearch escapes and formats for each field.
# Match offsets always refer to the original text, never to generated HTML.
class Search::Highlighter
  STEMMER = Mittens::Stemmer.new
  TOKEN = /(?:#{Search::CJK_PATTERN})\p{M}*|(?:(?!#{Search::CJK_PATTERN})[\p{L}\p{M}\p{N}_])+/

  def initialize(query)
    @phrases = query.scan(/"([^"]+)"|(\S+)/).map { |quoted, word| tokens(quoted || word).map(&:first) }
      .reject(&:empty?)
  end

  def highlight(text)
    mark(text, matching_ranges(tokens(text)))
  end

  def snippet(text, max_words:)
    words = tokens(text)
    ranges = matching_ranges(words)
    return text if ranges.empty?
    return mark(text, ranges) if words.size <= max_words

    match_index = words.index { |_, start, _| start == ranges.first.first }
    first = [ 0, match_index - max_words / 2 ].max
    last = [ words.size - 1, first + max_words - 1 ].min
    start = first.zero? ? 0 : words[first][1]
    finish = last == words.size - 1 ? text.length : words[last][2]
    clipped = ranges.filter_map do |left, right|
      [ [ left, start ].max - start, [ right, finish ].min - start ] if left < finish && right > start
    end
    excerpt = mark(text[start...finish], clipped)
    excerpt = "...#{excerpt}" if start > 0
    excerpt = "#{excerpt}..." if finish < text.length
    excerpt
  end

  private
    def tokens(text)
      text.to_enum(:scan, TOKEN).map do
        match = Regexp.last_match
        word = match[0].unicode_normalize(:nfc).downcase
        # unicode61 removes Latin diacritics before porter stemming.
        word = word.gsub(/\p{Latin}/) { |char| char.unicode_normalize(:nfd).gsub(/\p{M}/, "") }
        [ STEMMER.stem(word), match.begin(0), match.end(0) ]
      end
    end

    def matching_ranges(words)
      ranges = @phrases.flat_map do |phrase|
        words.each_cons(phrase.size).filter_map do |sequence|
          [ sequence.first[1], sequence.last[2] ] if sequence.map(&:first) == phrase
        end
      end.sort

      ranges.each_with_object([]) do |range, merged|
        if merged.any? && range.first <= merged.last.last
          merged.last[1] = [ merged.last.last, range.last ].max
        else
          merged << range
        end
      end
    end

    def mark(text, ranges)
      result = +""
      position = 0
      ranges.each do |left, right|
        result << text[position...left]
        result << ActiveSearch::Highlighting::STORE_OPEN_MARKER << text[left...right]
        result << ActiveSearch::Highlighting::STORE_CLOSE_MARKER
        position = right
      end
      result << text[position..]
    end
end
