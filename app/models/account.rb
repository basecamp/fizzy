class Account < ApplicationRecord
  include Entropic, Joinable

  has_many_attached :uploads

  class << self
    def create_with_admin_user(account:, owner:)
      User.create!(**owner.reverse_merge(role: "admin", password: SecureRandom.hex(16)))
      create!(**account)
    end
  end

  def slug
    "/#{tenant}"
  end

  def setup_basic_template
    user = User.first

    Closure::Reason.create_defaults
    Collection.create!(name: "Cards", creator: user, all_access: true)
  end
end
