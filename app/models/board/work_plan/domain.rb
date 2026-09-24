module Board::WorkPlan
  PlannerUser = Struct.new(:id, :name, keyword_init: true) do
    def to_h
      { id:, name: }
    end
  end

  WorkUnit = Struct.new(
    :id,
    :card_id,
    :card_number,
    :title,
    :due_on,
    :golden,
    :stalled,
    :urgency_weight,
    :assignee_id,
    :assignee_idx,
    :pinned,
    keyword_init: true
  ) do
    def to_h
      {
        id: id,
        card_id: card_id,
        card_number: card_number,
        title: title,
        due_on: due_on,
        golden: golden,
        stalled: stalled,
        urgency_weight: urgency_weight,
        assignee_id: assignee_id,
        assignee_idx: assignee_idx,
        pinned: pinned
      }
    end

    def pinned?
      pinned
    end
  end
end
