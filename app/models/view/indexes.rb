module View::Indexes
  INDEXES = %w[ most_active most_discussed most_boosted newest oldest popped ]

  def indexed_by
    filters["indexed_by"].to_s.inquiry
  end
end
