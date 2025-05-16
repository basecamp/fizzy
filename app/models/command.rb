class Command < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :user
  belongs_to :parent, class_name: "Command", optional: true

  scope :root, -> { where(parent_id: nil) }

  attribute :context

  def title
    model_name.human
  end

  def confirmation_prompt
    title
  end

  def execute
  end

  def undo
  end

  def undo!
    transaction do
      undo
      destroy
    end
  end

  def undoable?
    false
  end

  def needs_confirmation?
    false
  end

  private
    def redirect_to(...)
      Command::Result::Redirection.new(...)
    end
end
