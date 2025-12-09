module Account::Storage
  extend ActiveSupport::Concern
  include Storage::Totaled

  private
    def calculate_real_storage_bytes
      boards.sum { |board| board.send(:calculate_real_storage_bytes) }
    end
end
