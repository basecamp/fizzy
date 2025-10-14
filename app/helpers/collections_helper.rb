module CollectionsHelper
  def referenced_collections_from(records)
    Current.user.collections.where id: records.pluck(:collection_id).uniq
  end
end
