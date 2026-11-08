module ColumnFiltering
  extend ActiveSupport::Concern

  included do
    before_action :set_column_filter
  end

  private
    def set_column_filter
      if (filter_params = params.permit(*Filter::PERMITTED_PARAMS)).present?
        filter = Current.user.filters.from_params(filter_params)
        @column_filter = filter if filter.used?(ignore_boards: true)
      end
    end

    def filtered(cards)
      @column_filter ? @column_filter.apply_to(cards) : cards
    end
end
