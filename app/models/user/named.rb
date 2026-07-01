module User::Named
  extend ActiveSupport::Concern

  included do
    scope :alphabetically, -> { order("lower(name)") }
    
    # Sort users with selected IDs first, then unselected, both alphabetically
    # More efficient than in-memory sorting for large user lists
    scope :sorted_by_selection, ->(selected_ids) {
      return alphabetically if selected_ids.blank?
      
      # Convert string IDs to binary blobs for SQLite comparison
      uuid_type = ActiveRecord::Type::Uuid.new
      binary_ids = selected_ids.map { |id| uuid_type.serialize(id) }
      quoted_ids = binary_ids.map { |blob| connection.quote(blob) }.join(',')
      
      # Order by selection status FIRST, then alphabetically
      order(
        Arel.sql("CASE WHEN users.id IN (#{quoted_ids}) THEN 0 ELSE 1 END"),
        Arel.sql("LOWER(name)")
      )
    }
  end

  def first_name
    name.split(/\s/).first
  end

  def last_name
    name.split(/\s/, 2).last
  end

  def initials
    name.scan(/\b\p{L}/).join.upcase
  end

  def familiar_name
    names = name.split
    return name if names.length <= 1
    "#{names.first}\u00A0#{names[1..].map { |n| "#{n[0]}." }.join}"
  end
end
