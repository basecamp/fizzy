class User::Filtering
  attr_reader :user, :filter, :expanded

  delegate :as_params, :single_board, to: :filter
  delegate :only_closed?, to: :filter

  def initialize(user, filter, expanded: false)
    @user, @filter, @expanded = user, filter, expanded
  end

  def boards
    @boards ||= user.boards.ordered_by_recently_accessed
  end

  def selected_board_titles
    filter.board_titles
  end

  def selected_boards_label
    filter.boards_label
  end

  def tags
    @tags ||= account.tags.all.alphabetically
  end

  def users
    @users ||= account.users.active.alphabetically
  end

  def filters
    @filters ||= user.filters.all
  end

  def expanded?
    @expanded
  end

  def any?
    filter.used?(ignore_boards: true)
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

  def show_boards?
    filter.boards.any?
  end

  def single_board_or_first
    # Default to the first selected or, when no selection, to the first one
    filter.boards.first || boards.first
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key([ user, filter, expanded?, boards, tags, users, filters ], "user-filtering")
  end

  private
    def account
      user.account
    end
end
