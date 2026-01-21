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
        if target.is_a?(Symbol)
          "Notification::Push::#{target.to_s.classify}".constantize
        else
          target
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
end
