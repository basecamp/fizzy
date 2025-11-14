module ColumnScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_column
  end

  private
    def set_column
      @column = Current.account.columns.find(params[:column_id])
    end
end
