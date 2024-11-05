module Filter::Tags
  extend ActiveSupport::Concern

  included do
    store_accessor :params, :tag_ids
  end

  def tags
    @tags ||= account.tags.where id: tag_ids.to_s.split(",")
  end
end
