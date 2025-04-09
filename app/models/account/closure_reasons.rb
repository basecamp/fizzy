module Account::ClosureReasons
  extend ActiveSupport::Concern

  DEFAULT_LABELS = [
    "Completed",
    "Duplicate",
    "Maybe later",
    "Working as intended"
  ]

  FALLBACK_LABEL = "Done"

  included do
    has_many :closure_reasons, dependent: :destroy, class_name: "Closure::Reason" do
      def labels
        pluck(:label).presence || [ FALLBACK_LABEL ]
      end
    end

    after_create :create_default_closure_reasons
  end

  private
    def create_default_closure_reasons
      DEFAULT_LABELS.each do |label|
        closure_reasons.create! label: label
      end
    end
end
