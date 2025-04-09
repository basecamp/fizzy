module Filter::Params
  extend ActiveSupport::Concern

  PERMITTED_PARAMS = [
    :assignment_status,
    :indexed_by,
    assignee_ids: [],
    creator_ids: [],
    collection_ids: [],
    stage_ids: [],
    tag_ids: [],
    terms: []
  ]

  class_methods do
    def find_by_params(params)
      find_by params_digest: digest_params(params)
    end

    def digest_params(params)
      Digest::MD5.hexdigest normalize_params(params).to_json
    end

    def normalize_params(params)
      params.to_h.compact_blank.reject(&method(:default_value?)).sort
    end
  end

  included do
    before_save { self.params_digest = self.class.digest_params(as_params) }
  end

  # +as_params+ uses `resource#ids` instead of `#resource_ids`
  # because the latter won't work on unpersisted filters.
  def as_params
    {}.tap do |params|
      params[:indexed_by]        = indexed_by
      params[:assignment_status] = assignment_status
      params[:terms]             = terms
      params[:tag_ids]           = tags.ids
      params[:collection_ids]        = collections.ids
      params[:stage_ids]         = stages.ids
      params[:assignee_ids]      = assignees.ids
      params[:creator_ids]       = creators.ids
    end.compact_blank.reject(&method(:default_value?))
  end

  def as_params_without(key, value)
    as_params.tap do |params|
      if params[key].is_a?(Array)
        params[key] = params[key] - [ value ]
        params.delete(key) if params[key].empty?
      elsif params[key] == value
        params.delete(key)
      end
    end
  end
end
