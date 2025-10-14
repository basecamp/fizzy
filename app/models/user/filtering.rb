class User::Filtering
  include Rails.application.routes.url_helpers

  attr_reader :user, :filter, :expanded

  delegate :as_params, :single_collection, to: :filter
  delegate :only_closed?, to: :filter

  def initialize(user, filter, expanded: false)
    @user, @filter, @expanded = user, filter, expanded
  end

  def collections
    @collections ||= user.collections.ordered_by_recently_accessed
  end

  def selected_collection_titles
    filter.collection_titles
  end

  def selected_collections_label
    filter.collections_label
  end

  def tags
    @tags ||= Tag.all.alphabetically
  end

  def users
    @users ||= User.active.alphabetically
  end

  def filters
    @filters ||= Current.user.filters.all
  end

  def expanded?
    @expanded
  end

  def any?
    filter.used?(ignore_collections: true)
  end

  def show_indexed_by?
    !filter.indexed_by.all?
  end

  def show_sorted_by?
    !filter.sorted_by.latest?
  end

  def show_tags?
    return unless Tag.any?
    filter.tags.any?
  end

  def show_assignees?
    filter.assignees.any?
  end

  def show_creators?
    filter.creators.any?
  end

  def show_closers?
    filter.closers.any?
  end

  def show_collections?
    filter.collections.any?
  end

  def single_collection_or_first
    # Default to the first selected or, when no selection, to the first one
    filter.collections.first || collections.first
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key([ user, filter, expanded?, collections, tags, users, filters ], "user-filtering")
  end
end
