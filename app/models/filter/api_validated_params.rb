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

      if unsupported_keys.any?
        errors.add :base, "contains unsupported keys: #{unsupported_keys.join(", ")}"
      end
    end

    def validate_shapes
      ARRAY_FIELDS.each do |field|
        value = raw_params[field]

        unless value.nil? || value.is_a?(Array)
          errors.add field, "must be an array"
        end
      end
    end

    def validate_assignment_status
      if params[:assignment_status].present? && params[:assignment_status] != "unassigned"
        errors.add :assignment_status, "is invalid"
      end
    end

    def validate_indexed_by
      if params[:indexed_by].present? && !params[:indexed_by].in?(Filter::INDEXES)
        errors.add :indexed_by, "is invalid"
      end
    end

    def validate_sorted_by
      if params[:sorted_by].present? && !params[:sorted_by].in?(Filter::SORTED_BY)
        errors.add :sorted_by, "is invalid"
      end
    end

    def validate_creation
      validate_time_window :creation
    end

    def validate_closure
      validate_time_window :closure
    end

    def validate_time_window(field)
      if params[field].present? && !params[field].in?(TimeWindowParser::VALUES)
        errors.add field, "is invalid"
      end
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
      # Check the raw value first so malformed non-array inputs fail with a shape error.
      if raw_params[field].is_a?(Array)
        submitted_ids = Array(params[field]).compact_blank.uniq

        if submitted_ids.any?
          matched_ids = scope.where(id: submitted_ids).pluck(:id)

          if submitted_ids.sort != matched_ids.sort
            errors.add field, "contains unknown or inaccessible ids"
          end
        end
      end
    end

    def merged_source_params
      @merged_source_params ||= begin
        # Rails JSON wrapping can submit the same attributes both at the top level and
        # under :filter. Merge them so unsupported-key detection sees the full payload,
        # while preferring the wrapped values that Rails generated for this resource.
        submitted_params
          .except(:controller, :action, :format, :filter)
          .merge(submitted_params[:filter].is_a?(Hash) ? submitted_params[:filter].with_indifferent_access : {})
      end
    end
end
