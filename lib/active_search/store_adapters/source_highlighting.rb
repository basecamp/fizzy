module ActiveSearch
  module StoreAdapters
    module SourceHighlighting
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
            source = find_source(record, sources, index)
            fields = extract_source_fields(record, fields_to_extract, source)
            highlights = extract_record_highlights(record, query_context, source)

            {
              id: extract_document_id(record, index),
              score: record.try(:score).to_f,
              fields: fields,
              highlights: highlights
            }
          end

          { total: total, results: results }
        end

        def extract_source_fields(record, fields, source)
          extract_fields(record, fields)
        end

        # The display query is unchanged; adapters transform a copy for MATCH.
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
    end
  end
end
