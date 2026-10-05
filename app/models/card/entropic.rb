module Card::Entropic
  extend ActiveSupport::Concern

  included do
    scope :postponing_soon, -> do
      now = Time.now
      active
        .joins(board: :account)
        .left_outer_joins(board: :entropy)
        .joins("LEFT OUTER JOIN entropies AS account_entropies ON account_entropies.account_id = accounts.id AND account_entropies.container_type = 'Account' AND account_entropies.container_id = accounts.id")
        .where("last_active_at > #{connection.date_subtract('?', 'COALESCE(entropies.auto_postpone_period, account_entropies.auto_postpone_period)')}", now)
        .where("last_active_at <= #{connection.date_subtract('?', 'COALESCE(entropies.auto_postpone_period, account_entropies.auto_postpone_period) * 0.75')}", now)
    end

    delegate :auto_postpone_period, to: :board
  end

  class_methods do
    # Iterates per account, grouping the account's boards by their effective
    # auto-postpone period (board override, else account default). Each group
    # queries with a single constant cutoff, so `account_id = ? AND
    # last_active_at <= ?` rides the existing index instead of computing the
    # threshold per row across every card in the system.
    def auto_postpone_all_due(as_of: Time.now)
      failures = {}

      Account.find_each do |account|
        account.boards.active.includes(:entropy).group_by(&:auto_postpone_period).each do |period, boards|
          account.cards.active
            .where(board_id: boards.map(&:id))
            .where(last_active_at: ..(as_of - period))
            .find_each do |card|
              card.auto_postpone(user: account.system_user)
            rescue => error
              failures[card.id] = error
            end
        end
      end

      raise AutoPostponeError.new(failures) if failures.any?
    end
  end

  # Raised once the sweep has gone through every account, so one card that
  # can't be postponed doesn't stop the rest but still fails the job.
  class AutoPostponeError < StandardError
    DESCRIBED_FAILURES_LIMIT = 10

    attr_reader :failures

    def initialize(failures)
      @failures = failures
      super("Couldn't auto-postpone #{failures.size} #{"card".pluralize(failures.size)}: #{describe(failures)}")
    end

    private
      def describe(failures)
        described = failures.first(DESCRIBED_FAILURES_LIMIT).map { |card_id, error| "#{card_id} (#{error.class}: #{error.message})" }
        remaining = failures.size - described.size
        described << "and #{remaining} more" if remaining > 0
        described.join(", ")
      end
  end

  def entropy
    Card::Entropy.for(self)
  end

  def entropic?
    entropy.present?
  end
end
