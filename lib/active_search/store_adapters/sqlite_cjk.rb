module ActiveSearch
  module StoreAdapters
    class SQLiteCjk < Sqlite
      include SourceHighlighting

      # Only CJK needs application tokenization. FTS5's porter tokenizer still owns
      # English stemming, and source records supply unmodified display text.
      def write_fts_row(model, fts_table, rowid, text_fields, data)
        tokenized = data.dup
        text_fields.each { |field| tokenized[field] = tokenize_cjk(data[field]) }
        super(model, fts_table, rowid, text_fields, tokenized)
      end

      private
        def tokenize_cjk(text)
          text&.unicode_normalize(:nfc)&.gsub(Search::CJK_PATTERN, ' \\0 ')
        end

        def build_fts_query(query_context)
          query = query_context.query.gsub(/"[^"]*"|\S+/) do |term|
            if term.match?(Search::CJK_PATTERN)
              # Keep a contiguous CJK query a phrase, rather than an unordered AND.
              "\"#{tokenize_cjk(term.delete('"')).strip}\""
            else
              term
            end
          end
          super(query_context.with(query: query))
        end

        def extract_source_fields(record, fields, source)
          super.tap do |values|
            if source
              (fields.map(&:to_sym) & HIGHLIGHT_SOURCES.keys).each do |field|
                values[field] = fetch_highlight_value(field, record, source)
              end
            end
          end
        end

        def highlight_select(*)
          []
        end

        def highlight_text(text, query)
          Search::Highlighter.new(query).highlight(text)
        end

        def highlight_snippet(text, query, field_opts)
          words = field_opts.snippet_value || ActiveSearch::Highlighting::FieldOptions::DEFAULT_SNIPPET_WORDS
          Search::Highlighter.new(query).snippet(text, max_words: words)
        end
    end
  end
end
