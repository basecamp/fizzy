class Collection < ApplicationRecord
  include Accessible, Broadcastable, Filterable

  belongs_to :account
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :workflow, optional: true

  has_many :cards, dependent: :destroy
  has_many :tags, -> { distinct }, through: :cards

  validates_presence_of :name

  after_save :update_cards_workflow, if: :saved_change_to_workflow_id?

  scope :alphabetically, -> { order("lower(name)") }

  private
    def update_cards_workflow
      cards.update_all(stage_id: workflow&.stages&.first&.id)
    end
end
