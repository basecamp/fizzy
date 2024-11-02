module View::Indexes
  INDEXES = %w[ most_active most_discussed most_boosted newest oldest popped ]

  def indexed_by
    (filters["indexed_by"] || self.class.default_indexed_by).inquiry
  end
end
