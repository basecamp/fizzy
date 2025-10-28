module User::Identifiable
  extend ActiveSupport::Concern

  included do
    belongs_to :membership, optional: true
    has_one :identity, through: :membership, disable_joins: true
  end
end
