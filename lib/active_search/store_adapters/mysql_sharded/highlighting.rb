module ActiveSearch
  module StoreAdapters
    class MysqlSharded < Mysql
      module Highlighting
        HIGHLIGHT_SOURCES = {
          title: ->(record) { record.is_a?(Card) ? record.title : record.card.title },
          content: ->(record) { record.is_a?(Card) ? record.description&.to_plain_text : record.body&.to_plain_text }
        }.freeze

        HIGHLIGHT_PRELOADS = {
          "Card" => [ :rich_text_description ],
          "Comment" => [ :card, :rich_text_body ]
        }.freeze

        private
          def execute_query(index, raw_query, query_context, routing: nil)
            records = raw_query.to_a
            sources = preload_highlight_sources(records, index)

            total = raw_query.unscope(:limit, :offset, :select, :order).count(:all)
            fields_to_extract = query_context.hit_fields || index.definition.fields.map(&:name)

            results = records.map do |record|
              fields = extract_fields(record, fields_to_extract)
              highlights = extract_record_highlights(record, query_context, find_source(record, sources, index))

              {
                id: extract_document_id(record, index),
                score: record.try(:score).to_f,
                fields: fields,
                highlights: highlights
              }
            end

            { total: total, results: results }
          end

          # This query_context is unstemmed: build_raw_query stemmed a copy for MATCH.
          def extract_record_highlights(record, query_context, source_record = nil)
            terms = query_context.query
            return {} unless query_context.highlight_opts && terms.present?

            highlights = {}

            query_context.fields&.each do |field|
              field_opts = query_context.highlight_opts.for_field(field)
              raw_value = fetch_highlight_value(field, record, source_record)

              next unless raw_value.present?

              marked = if field_opts.snippet?
                highlight_snippet(raw_value, terms, field_opts)
              else
                highlight_text(raw_value, terms)
              end

              # fragment escapes, and answers nil when nothing was marked.
              fragment = ActiveSearch::Highlighting.fragment(marked, field_opts)
              highlights[field.to_sym] = fragment if fragment
            end

            highlights
          end

          def preload_highlight_sources(records, index)
            type_col = index.source.type_column
            id_col = index.source.id_column

            by_type = records.group_by { |r| r.try(type_col) }.reject { |k, _| k.blank? }
            sources = {}

            by_type.each do |type, type_records|
              model = type.safe_constantize
              next unless model

              ids = type_records.map { |r| r.try(id_col) }.compact
              model.where(id: ids).includes(*HIGHLIGHT_PRELOADS.fetch(type, [])).each do |source|
                sources[[ type, source.id ]] = source
              end
            end

            sources
          end

          def find_source(record, sources, index)
            type_col = index.source.type_column
            id_col = index.source.id_column
            sources[[ record.try(type_col), record.try(id_col) ]]
          end

          def fetch_highlight_value(field, record, source_record)
            if source_record
              accessor = HIGHLIGHT_SOURCES[field] || HIGHLIGHT_SOURCES[field.to_sym]
              if accessor.respond_to?(:call)
                accessor.call(source_record)
              elsif accessor
                source_record.try(accessor)
              else
                record.try(field)
              end
            else
              record.try(field)
            end
          end

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
