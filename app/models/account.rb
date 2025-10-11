class Account < ApplicationRecord
  include Entropic, Joinable

  has_many_attached :uploads

  enum :setup_status, %w[ pending complete ].index_by(&:itself), prefix: :setup, default: :pending

  class << self
    def create_with_admin_user(account:, owner:)
      User.system
      User.create!(**owner.reverse_merge(role: "admin", password: SecureRandom.hex(16)))
      create!(**account)
    end
  end

  def slug
    "/#{tenant}"
  end

  def setup_basic_template
    user = User.first

    Collection.create!(name: "Cards", creator: user, all_access: true)
  end
end
