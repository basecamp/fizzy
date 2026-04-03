class Filter::ApiValidatedParams
  include ActiveModel::Model
  include ActiveModel::Validations

  ARRAY_FIELDS = %i[assignee_ids creator_ids closer_ids board_ids tag_ids terms].freeze
  SCALAR_FIELDS = %i[assignment_status indexed_by sorted_by creation closure].freeze
  PERMITTED_PARAMS = [ *SCALAR_FIELDS, *ARRAY_FIELDS.index_with { [] } ].freeze

  attr_reader :user, :raw_params, :submitted_params

  validate :validate_unsupported_keys
  validate :validate_shapes
  validate :validate_assignment_status
  validate :validate_indexed_by
  validate :validate_sorted_by
  validate :validate_creation
  validate :validate_closure
  validate :validate_assignee_ids
  validate :validate_creator_ids
  validate :validate_closer_ids
  validate :validate_board_ids
  validate :validate_tag_ids

  def initialize(user, raw_params)
    @user = user
    @submitted_params = (raw_params || {}).with_indifferent_access
    @raw_params = merged_source_params.slice(*SCALAR_FIELDS, *ARRAY_FIELDS)
  end

  def params
    @params ||= Filter.normalize_params(raw_params).with_indifferent_access
  end

  private
    def validate_unsupported_keys
      unsupported_keys = merged_source_params.except(*SCALAR_FIELDS, *ARRAY_FIELDS).keys
      return if unsupported_keys.empty?

      errors.add :base, "contains unsupported keys"
    end

    def validate_shapes
      ARRAY_FIELDS.each do |field|
        value = raw_params[field]
        next if value.nil? || value.is_a?(Array)

        errors.add field, "must be an array"
      end
    end

    def validate_assignment_status
      return if params[:assignment_status].blank? || params[:assignment_status] == "unassigned"

      errors.add :assignment_status, "is invalid"
    end

    def validate_indexed_by
      return if params[:indexed_by].blank? || params[:indexed_by].in?(Filter::INDEXES)

      errors.add :indexed_by, "is invalid"
    end

    def validate_sorted_by
      return if params[:sorted_by].blank? || params[:sorted_by].in?(Filter::SORTED_BY)

      errors.add :sorted_by, "is invalid"
    end

    def validate_creation
      validate_time_window :creation
    end

    def validate_closure
      validate_time_window :closure
    end

    def validate_time_window(field)
      return if params[field].blank? || params[field].in?(TimeWindowParser::VALUES)

      errors.add field, "is invalid"
    end

    def validate_assignee_ids
      validate_ids :assignee_ids, user.account.users.active
    end

    def validate_creator_ids
      validate_ids :creator_ids, user.account.users.active
    end

    def validate_closer_ids
      validate_ids :closer_ids, user.account.users.active
    end

    def validate_board_ids
      validate_ids :board_ids, user.boards
    end

    def validate_tag_ids
      validate_ids :tag_ids, user.account.tags
    end

    def validate_ids(field, scope)
      return unless raw_params[field].is_a?(Array)

      submitted_ids = Array(params[field]).compact_blank.uniq
      return if submitted_ids.empty?

      matched_ids = scope.where(id: submitted_ids).pluck(:id)
      errors.add field, "contains unknown or inaccessible ids" if submitted_ids.sort != matched_ids.sort
    end

    def merged_source_params
      @merged_source_params ||= begin
        submitted_params
          .except(:controller, :action, :format, :filter)
          .merge(submitted_params[:filter].is_a?(Hash) ? submitted_params[:filter].with_indifferent_access : {})
      end
    end
end
