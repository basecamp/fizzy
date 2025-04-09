module Filter::Params
  extend ActiveSupport::Concern

  PERMITTED_PARAMS = %i[
    indexed_by assignment_status collection_ids creator_ids
    assignee_ids stage_ids tag_ids terms display_count
  ].freeze

  def as_params
    self.class.normalize_params(
      indexed_by: indexed_by,
      assignment_status: assignment_status,
      collection_ids: collections.ids,
      creator_ids: creators.ids,
      assignee_ids: assignees.ids,
      stage_ids: stages.ids,
      tag_ids: tags.ids,
      terms: terms,
      display_count: display_count
    )
  end
end
