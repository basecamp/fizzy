# Groups a board's published cards into an ordered set of phase groups, with
# each card's status rolled up from its native state (closure, not-now,
# activity spike, column) rather than from the column it happens to sit in.
class Board::Roadmap
  STATUS_ORDER = %i[ shipped in_flight stalled planned not_now ].freeze

  RoadmapCard = Data.define(:card, :title, :number, :status, :type, :domains, :steps_completed, :steps_total) do
    def status_rank = STATUS_ORDER.index(status)
  end

  PhaseGroup = Data.define(:label, :title, :epics, :cards, :rollup) do
    def all_cards
      epics + cards
    end

    def ordered_cards
      epics.sort_by(&:status_rank) + cards.sort_by(&:status_rank)
    end
  end

  Rollup = Data.define(:shipped, :not_now, :stalled, :in_flight, :planned) do
    def total
      shipped + not_now + stalled + in_flight + planned
    end
  end

  Summary = Data.define(:total_epics, :epics_shipped, :in_flight, :deferred, :planned)

  PHASE_NAMESPACE_PATTERN = /\Aphase:(.+)\z/
  PHASE_BARE_PATTERN = /\Ap(\d+)\z/
  DOMAIN_NAMESPACE_PATTERN = /\Adomain:(.+)\z/
  EPIC_TITLES = %w[ type:epic epic ]
  UNPHASED_LABEL = "unphased"

  def initialize(board)
    @board = board
  end

  def phase_groups
    @phase_groups ||= build_phase_groups
  end

  def summary
    @summary ||= build_summary
  end

  private
    attr_reader :board

    def build_phase_groups
      cards_by_phase_label = cards.group_by { |card| phase_label_for(card) }

      labels = (cards_by_phase_label.keys - [ UNPHASED_LABEL ]).sort_by { |label| phase_sort_key(label) }
      labels << UNPHASED_LABEL if cards_by_phase_label.key?(UNPHASED_LABEL)

      labels.map do |label|
        roadmap_cards = cards_by_phase_label[label].map { |card| roadmap_card_for(card) }
        epics, stories = roadmap_cards.partition { |roadmap_card| roadmap_card.type == :epic }

        PhaseGroup.new(
          label: label,
          title: phase_title_for(label),
          epics: epics,
          cards: stories,
          rollup: rollup_for(roadmap_cards)
        )
      end
    end

    def build_summary
      roadmap_cards = phase_groups.flat_map(&:all_cards)
      epics = roadmap_cards.select { |roadmap_card| roadmap_card.type == :epic }

      Summary.new(
        total_epics: epics.size,
        epics_shipped: epics.count { |roadmap_card| roadmap_card.status == :shipped },
        in_flight: roadmap_cards.count { |roadmap_card| roadmap_card.status == :in_flight },
        deferred: roadmap_cards.count { |roadmap_card| roadmap_card.status == :not_now },
        planned: roadmap_cards.count { |roadmap_card| roadmap_card.status == :planned }
      )
    end

    def cards
      @cards ||= board.cards.published
        .preload(:tags, :closure, :not_now, :activity_spike, :column, :steps)
        .to_a
    end

    def roadmap_card_for(card)
      RoadmapCard.new(
        card: card,
        title: card.title,
        number: card.number,
        status: status_for(card),
        type: type_for(card),
        domains: domains_for(card),
        steps_completed: card.steps.count(&:completed?),
        steps_total: card.steps.size
      )
    end

    # Status is derived from the card's native state (closure, not-now,
    # stalled activity, having a column), never from the column it sits in.
    def status_for(card)
      if card.closed?
        :shipped
      elsif card.postponed?
        :not_now
      elsif card.stalled?
        :stalled
      elsif card.triaged?
        :in_flight
      else
        :planned
      end
    end

    def rollup_for(roadmap_cards)
      Rollup.new(
        shipped: roadmap_cards.count { |roadmap_card| roadmap_card.status == :shipped },
        not_now: roadmap_cards.count { |roadmap_card| roadmap_card.status == :not_now },
        stalled: roadmap_cards.count { |roadmap_card| roadmap_card.status == :stalled },
        in_flight: roadmap_cards.count { |roadmap_card| roadmap_card.status == :in_flight },
        planned: roadmap_cards.count { |roadmap_card| roadmap_card.status == :planned }
      )
    end

    # Namespaced tag wins over its bare fallback; among several recognized
    # phase tags on one card, the lowest-ordered phase wins so grouping is
    # deterministic regardless of tagging order.
    def phase_label_for(card)
      labels = card.tags.filter_map { |tag| phase_label(tag.title) }
      labels.any? ? labels.min_by { |label| phase_sort_key(label) } : UNPHASED_LABEL
    end

    def phase_label(title)
      if (match = title.match(PHASE_NAMESPACE_PATTERN))
        match[1]
      elsif title.match?(PHASE_BARE_PATTERN)
        title
      end
    end

    def phase_sort_key(label)
      if (match = label.match(PHASE_BARE_PATTERN))
        [ 0, match[1].to_i, label ]
      else
        [ 1, 0, label ]
      end
    end

    def phase_title_for(label)
      if label == UNPHASED_LABEL
        "Unphased"
      elsif (match = label.match(PHASE_BARE_PATTERN))
        "P#{match[1]}"
      else
        label.titleize
      end
    end

    # Anything not recognized as an epic (including no type tag, or an
    # explicit story tag) defaults to a plain, story-level card.
    def type_for(card)
      card.tags.any? { |tag| tag.title.in?(EPIC_TITLES) } ? :epic : :story
    end

    def domains_for(card)
      card.tags.filter_map { |tag| tag.title[DOMAIN_NAMESPACE_PATTERN, 1] }
    end
end
