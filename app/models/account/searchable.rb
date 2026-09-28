module Account::Searchable
  extend ActiveSupport::Concern

  included do
    # Nothing writes these any more; kept so incineration still clears the rows.
    has_many :search_queries, class_name: "Search::Query", dependent: :delete_all

    before_destroy :clear_search_records
  end

  private
    def clear_search_records
      ActiveSearch.index(:searchable).remove_by_filter(account_id: id)
    end
end
