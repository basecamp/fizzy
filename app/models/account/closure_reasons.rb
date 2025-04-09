module Account::PopReasons
  extend ActiveSupport::Concern

  DEFAULT_LABELS = [
    "Completed",
    "Duplicate",
    "Maybe later",
    "Working as intended"
  ]

  FALLBACK_LABEL = "Done"

  included do
    has_many :pop_reasons, dependent: :destroy, class_name: "Pop::Reason" do
      def labels
        pluck(:label).presence || [ FALLBACK_LABEL ]
      end
    end

    after_create :create_default_pop_reasons
  end

  private
    def create_default_pop_reasons
      DEFAULT_LABELS.each do |label|
        pop_reasons.create! label: label
      end
    end
end
