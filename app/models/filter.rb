class Filter < ApplicationRecord
  include Fields, Params, Resources, Summarized

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { creator.account }

  class << self
    def from_params(params)
      find_by_params(params) || build(params)
    end

    def remember(attrs)
      create!(attrs)
    rescue ActiveRecord::RecordNotUnique
      find_by_params(attrs).tap(&:touch)
    end
  end

  def cards
    @cards ||= begin
      result = creator.accessible_cards.preloaded.published
      result = result.indexed_by(indexed_by)
      result = result.sorted_by(sorted_by)
      result = result.where(id: card_ids) if card_ids.present?
      result = result.where.missing(:not_now) unless include_not_now_cards?
      result = result.open unless include_closed_cards?
      result = result.unassigned if assignment_status.unassigned?
      result = result.assigned_to(assignees.ids) if assignees.present?
      result = result.where(creator_id: creators.ids) if creators.present?
      result = filter_boards(result) if boards.present?
      result = result.tagged_with(tags.ids) if tags.present?
      result = result.where(cards: { created_at: creation_window }) if creation_window
      result = result.closed_at_window(closure_window) if closure_window
      result = result.closed_by(closers) if closers.present?
      result = terms.reduce(result) do |result, term|
        result.mentioning(term, user: creator)
      end
      result = result.where(column_id: column_ids) if column_ids.present?

      result.distinct
    end
  end

  def empty?
    self.class.normalize_params(as_params).blank?
  end

  def single_board
    boards.first if boards.one?
  end

  def single_workflow
    boards.first.workflow if boards.pluck(:workflow_id).uniq.one?
  end

  def cacheable?
    boards.exists?
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key params_digest, "filter"
  end

  def only_closed?
    indexed_by.closed? || closure_window || closers.present?
  end

  private
    def filter_boards(relation)
      relation = relation.where(cards: { account_id: creator.account_id }).where(board: boards.ids)
      if joins_has_many?
        relation
      else
        # Pin the (account_id, last_active_at, status) index so the ordered page is served by a reverse scan, not a filesort.
        relation.use_index(:index_cards_on_account_id_and_last_active_at_and_status)
      end
    end

    # Assignee, tag, and term filters add a has-many join that fans a card into
    # several rows; the ordered reverse scan loses to a different plan then, so
    # the pin only applies without them.
    def joins_has_many?
      assignees.present? || tags.present? || terms.present?
    end

    def include_closed_cards?
      only_closed? || card_ids.present?
    end

    def include_not_now_cards?
      indexed_by.not_now? || card_ids.present?
    end
end
