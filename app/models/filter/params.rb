module Filter::Params
  extend ActiveSupport::Concern

  PERMITTED_PARAMS = [ :assignment_status, :bubble_limit, :indexed_by, assignee_ids: [], assigner_ids: [], bucket_ids: [], tag_ids: [], terms: [] ]

  class_methods do
    def find_by_params(params)
      find_by params_digest: digest_params(params)
    end

    def digest_params(params)
      Digest::MD5.hexdigest normalize_params(params.to_h).to_json
    end

    def normalize_params(params)
      params.sort.to_h.compact_blank
        .reject { |key, value| default_fields[key.to_s].eql?(value) }
        .transform_values { |value| value.is_a?(Array) ? value.map(&:to_s) : value.to_s }
    end
  end

  included do
    before_save { self.params_digest = digest_params(to_params) }
  end

  def to_query
    {}.tap do |params|
      params[:bubble_limit]      = bubble_limit
      params[:terms]             = terms
      params[:indexed_by]        = indexed_by
      params[:assignment_status] = assignment_status
      params[:tag_ids]           = resource_ids_for tags
      params[:bucket_ids]        = resource_ids_for buckets
      params[:assignee_ids]      = resource_ids_for assignees
      params[:assigner_ids]      = resource_ids_for assigners
    end.then(&method(:normalize_params)).compact_blank
  end

  def to_query_without(key, value)
    to_query.tap do |params|
      params[key].delete(value) if params[key].is_a?(Array)
      params.delete(key) if params[key] == value
    end
  end

  private
    delegate :digest_params, :normalize_params, to: :class, private: true

    def to_params
      ActionController::Parameters.new(to_query).permit(*PERMITTED_PARAMS)
    end
end
