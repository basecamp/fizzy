module Fizzy
  module Saas
    module JobMemory
      extend ActiveSupport::Concern

      included do
        around_perform :record_memory, if: -> { ENV["LOG_JOB_MEMORY"] == "true" }
      end

      private
        def record_memory(&block)
          Memory::Stats.new(logger).collect(&block)
        end
    end
  end
end
