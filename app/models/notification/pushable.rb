module Notification::Pushable
  extend ActiveSupport::Concern

  included do
    class_attribute :push_targets, default: []

    after_create_commit :push_later
    after_update_commit :push_later, if: :source_id_previously_changed?
  end

  class_methods do
    def register_push_target(target)
      target = resolve_push_target(target)
      push_targets << target unless push_targets.include?(target)
    end

    private
      def resolve_push_target(target)
        if target.is_a?(Notification::PushTarget) then target
        else
          "Notification::PushTarget::#{target.to_s.classify}".constantize
        end
      end
  end

  def push_later
    self.class.push_targets.each do |target|
      target.push_later(self)
    end
  end

  def pushable?
    !creator.system? && user.active? && account.active?
  end

  def payload
    "Notification::#{payload_type}Payload".constantize.new(self)
  end

  private
    def payload_type
      source_type.presence_in(%w[ Event Mention ]) || "Default"
    end
end
