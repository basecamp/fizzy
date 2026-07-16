class Account::DataTransfer::RecordSet::DuplicateDetector
  def initialize(key_sets)
    @key_sets = key_sets
    @seen = Hash.new { |seen, columns| seen[columns] = Set.new }
  end

  def detect(data)
    key_sets.find do |columns|
      values = data.values_at(*columns)
      values.none?(&:nil?) && !seen[columns].add?(digest(values))
    end
  end

  private
    attr_reader :key_sets, :seen

    # NOTE: The digest is here to avoid storing whole row values in memory, which could be quite large.
    # (remeber, the value is user controlled, someone could craft a malicious import to baloon memory)
    # This is an improvement, but it still could be a problem if the number of unique values is very large.
    # In that case, we may need to use a more memory-efficient approach, such as storing the digests in a
    # temporary file, or we could switch to a Bloom filter, or a Merkel tree.
    # MySQL's default collation compares strings case-insensitively, and UUID columns
    # cast their values through base36, so values differing only in case are duplicates.
    def digest(values)
      Digest::SHA256.digest(values.map { |value| value.is_a?(String) ? value.downcase : value }.to_json)
    end
end
