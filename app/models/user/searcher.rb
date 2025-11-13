module User::Searcher
  extend ActiveSupport::Concern

  included do
    has_many :search_queries, class_name: "Search::Query", dependent: :destroy
  end

  def search(terms)
    Search.results(query: terms, user: self)
  end

  def remember_search(terms)
    search_queries.find_or_create_by(terms: terms).tap do |search_query|
      search_query.touch unless search_query.invalid? || search_query.previously_new_record?
    end
  end
end
