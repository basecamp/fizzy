module User::Identifiable
  extend ActiveSupport::Concern

  included do
    belongs_to :membership
    has_one :identity, through: :membership

    after_create_commit :link_identity, unless: :system?
    after_destroy_commit :unlink_identity, unless: :system?
  end

  def identity
    Identity.find_by(email_address: email_address)
  end

  private
    def link_identity
      Identity.link(email_address: email_address, to: tenant)
    end

    def unlink_identity
      Identity.unlink(email_address: email_address, from: tenant)
    end
end
