module ColumnFiltering
  extend ActiveSupport::Concern

  included do
    include SearchRateLimiting

    before_action :set_column_filter
    limit_searches
  end

  private
    def set_column_filter
      if (filter_params = params.permit(*Filter::PERMITTED_PARAMS)).present?
        filter = Current.user.filters.from_params(filter_params)
        @column_filter = filter if filter.used?(ignore_boards: true)
      end
    end

    def searching?
      @column_filter&.terms.present?
    end

    def filtered(cards)
      @column_filter ? @column_filter.apply_to(cards) : cards
    end
end
