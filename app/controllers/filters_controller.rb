class FiltersController < ApplicationController
  before_action :set_filter, only: %i[show destroy]

  def index
    @filters = Current.user.filters.order(updated_at: :desc)
  end

  def show
  end

  def create
    respond_to do |format|
      format.turbo_stream do
        @filter = Current.user.filters.remember(html_filter_params)
      end

      format.json do
        validated_params = Filter::ApiValidatedParams.new(Current.user, params.to_unsafe_h)

        if validated_params.invalid?
          render json: { errors: validated_params.errors.to_hash }, status: :unprocessable_entity
        else
          existing_filter = Current.user.filters.find_by_params(validated_params.params)
          @filter = Current.user.filters.remember(validated_params.params)

          render :show, status: (existing_filter ? :ok : :created), location: filter_url(@filter, format: :json)
        end
      end
    end
  end

  def destroy
    @filter.destroy!

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def set_filter
      @filter = Current.user.filters.find(params[:id])
    end

    def html_filter_params
      Filter.normalize_params(params.permit(*Filter::PERMITTED_PARAMS))
    end
end
