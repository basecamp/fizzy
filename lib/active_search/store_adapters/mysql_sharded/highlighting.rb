module ActiveSearch
  module StoreAdapters
    class MysqlSharded < Mysql
      module Highlighting
          # Not \w, which is ASCII: "café" would be marked only up to the accent.
          WORD = /[[:word:]]+/

          # Mark with the gem's sentinels, never the configured markers: fragment substitutes
          # them after escaping, so a literal <mark> in a card cannot forge a highlight.
          def highlight_text(text, query)
            stems = query_stems(query)
            return text if stems.empty?

            text.gsub(WORD) do |word|
              if stem_tokens(word).intersect?(stems)
                "#{ActiveSearch::Highlighting::STORE_OPEN_MARKER}#{word}" \
                  "#{ActiveSearch::Highlighting::STORE_CLOSE_MARKER}"
              else
                word
              end
            end
          end

          # Words only: capabilities declares :words, so a characters snippet never gets here.
          def highlight_snippet(text, query, field_opts)
            max_words = field_opts.snippet_value ||
              ActiveSearch::Highlighting::FieldOptions::DEFAULT_SNIPPET_WORDS
            words = text.split(/\s+/)
            stems = query_stems(query)
            match_index = words.index { |word| stem_tokens(word).intersect?(stems) }

            if words.length <= max_words
              highlight_text(text, query)
            elsif match_index
              start_index = [ 0, match_index - max_words / 2 ].max
              end_index = [ words.length - 1, start_index + max_words - 1 ].min

              snippet_text = words[start_index..end_index].join(" ")
              snippet_text = "...#{snippet_text}" if start_index > 0
              snippet_text = "#{snippet_text}..." if end_index < words.length - 1

              highlight_text(snippet_text, query)
            else
              text.truncate_words(max_words, omission: "...")
            end
          end

          # Quotes carry no phrase meaning: stem strips them before MATCH, so mark the
          # words of a quoted pair separately.
          def query_stems(query)
            highlight_terms(query).flat_map { |term| stem_tokens(term) }.reject(&:blank?).uniq
          end

          def highlight_terms(query)
            terms = []

            query.scan(/"([^"]+)"/) do |phrase|
              terms << phrase.first
            end

            unquoted = query.gsub(/"[^"]+"/, "")
            unquoted.split(/\s+/).each do |word|
              terms << word if word.present?
            end

            terms.uniq
          end
      end
    end
  end
end
