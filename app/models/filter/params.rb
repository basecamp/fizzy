# rbs_inline: enabled

module Filter::Params
  extend ActiveSupport::Concern

  # @type self: singleton(Filter) & singleton(Filter::Params)

  PERMITTED_PARAMS = [
    :assignment_status,
    :indexed_by,
    :sorted_by,
    :creation,
    :closure,
    card_ids: [],
    assignee_ids: [],
    creator_ids: [],
    closer_ids: [],
    board_ids: [],
    tag_ids: [],
    terms: []
  ]

  class_methods do
    def find_by_params(params)
      # @type self: singleton(Filter) & singleton(Filter::Params)
      find_by params_digest: digest_params(params)
    end

    def digest_params(params)
      Digest::MD5.hexdigest normalize_params(params).to_json
    end

    def normalize_params(params)
      params
        .to_h
        .compact_blank
        .reject(&method(:default_value?))
        .collect { |name, value| [ name, value.is_a?(Array) ? value.collect(&:to_s) : value.to_s ] }
        .sort_by { |name, _| name.to_s }
        .to_h
    end
  end

  included do
    before_save { self.params_digest = self.class.digest_params(as_params) }
  end

  def used?(ignore_boards: false)
    # @type self: Filter & Filter::Params
    tags.any? || assignees.any? || creators.any? || closers.any? ||
      terms.any? || card_ids&.any? || (!ignore_boards && boards.present?) ||
      assignment_status.unassigned? || !indexed_by.all? || !sorted_by.latest?
  end

  # +as_params+ uses `resource#ids` instead of `#resource_ids`
  # because the latter won't work on unpersisted filters.
  def as_params
    # @type self: Filter & Filter::Params
    @as_params ||= {}.tap do |params|
      params[:indexed_by]        = indexed_by
      params[:sorted_by]         = sorted_by
      params[:creation]          = creation
      params[:closure]           = closure
      params[:assignment_status] = assignment_status
      params[:terms]             = terms
      params[:tag_ids]           = tags.ids
      params[:board_ids]    = boards.ids
      params[:card_ids]          = card_ids
      params[:assignee_ids]      = assignees.ids
      params[:creator_ids]       = creators.ids
      params[:closer_ids]        = closers.ids
    end.compact_blank.reject(&method(:default_value?))
  end

  def as_params_without(key, value)
    as_params.dup.tap do |params|
      if params[key].is_a?(Array)
        params[key] = params[key] - [ value ]
        params.delete(key) if params[key].empty?
      elsif params[key] == value
        params.delete(key)
      end
    end
  end

  def params_digest
    super.presence || self.class.digest_params(as_params)
  end
end
