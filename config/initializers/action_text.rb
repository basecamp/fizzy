module ActionText
  module Extensions
    module RichText
      extend ActiveSupport::Concern

      included do
        # This overrides the default :embeds association!
        has_many_attached :embeds do |attachable|
          ::Attachments::VARIANTS.each do |variant_name, variant_options|
            attachable.variant variant_name, **variant_options, process: :immediately
          end
        end
      end

      # Delegate storage tracking to the parent record (Card, Comment, Board, etc.)
      def storage_tracked_record
        record.try(:storage_tracked_record)
      end

      def accessible_to?(user)
        record.try(:accessible_to?, user) || record.try(:publicly_accessible?)
      end

      def publicly_accessible?
        record.try(:publicly_accessible?)
      end
    end
  end
end

ActiveSupport.on_load(:action_text_rich_text) do
  include ActionText::Extensions::RichText
end
