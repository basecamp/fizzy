require "mittens"

module ActiveSearch
  module StoreAdapters
    class MysqlSharded < Mysql
      module Stemming
        STEMMER = Mittens::Stemmer.new

        private
          def stem_document_data(document)
            data = document.data.dup
            data[:account_key] = "account#{data[:account_id]}" if data[:account_id]
            document.definition.search_fields.each do |field|
              data[field] = stem(data[field].to_s) if data[field].present?
            end
            data
          end

          def stem_query_context(query_context, routing)
            return query_context unless query_context.query.present?
            stemmed = stem(query_context.query)
            full_query = "+account#{routing} +(#{stemmed})"
            query_context.with(query: full_query)
          end

          def stem(value)
            if value.present?
              stem_tokens(value).join(" ")
            else
              value
            end
          end

          # The one definition of an index token: documents, queries and highlighting
          # must all tokenise the same way or a mark lands where MySQL did not match.
          def stem_tokens(value)
            value.to_s.unicode_normalize(:nfc).gsub(/[^\p{L}\p{M}\p{N}_\s]/, " ").split(/\s+/).map { |word| STEMMER.stem(word.downcase) }
          end
      end
    end
  end
end
