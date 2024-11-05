module Filter::Indexes
  INDEXES = %w[ most_active most_discussed most_boosted newest oldest popped ]

  def indexed_by
    (params["indexed_by"] || self.class.default_params["indexed_by"]).inquiry
  end
end
