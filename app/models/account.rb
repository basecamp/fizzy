class Account < ApplicationRecord
  include Entropic

  has_many_attached :uploads

  after_create :create_join_code

  validates :name, presence: true

  class << self
    def create_with_admin_user(account:, owner:)
      create!(**account).tap do
        User.system
        User.create!(**owner.reverse_merge(role: "admin"))
      end
    end
  end

  # To use the account as a generic card container. See +Entropy+.
  def cards
    Card.all
  end

  def slug
    "/#{tenant}"
  end

  def setup_basic_template
    user = User.first

    Collection.create!(name: "Cards", creator: user, all_access: true)
  end

  private
    def create_join_code
      Account::JoinCode.create!
    end
end
