module CachingTestHelper
  def with_actionview_partial_caching
    was_cache = ActionView::PartialRenderer.collection_cache
    was_perform_caching = ApplicationController.perform_caching
    begin
      ActionView::PartialRenderer.collection_cache = ActiveSupport::Cache.lookup_store(:memory_store)
      ApplicationController.perform_caching = true
      yield
    ensure
      ActionView::PartialRenderer.collection_cache = was_cache
      ApplicationController.perform_caching = was_perform_caching
    end
  end
end
