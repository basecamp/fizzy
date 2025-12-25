# rbs_inline: enabled


# Tell crawlers like Googlebot to drop pages entirely from search results, even
# if other sites link to it
module BlockSearchEngineIndexing
  extend ActiveSupport::Concern

  included do
    after_action :block_search_engine_indexing
  end

  private
    def block_search_engine_indexing
      headers["X-Robots-Tag"] = "none"
    end
end
