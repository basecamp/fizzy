module Board::WorkPlan
  PlannerUser = Struct.new(:id, :name, keyword_init: true) do
    def to_h
      { id:, name: }
    end
  end
end
