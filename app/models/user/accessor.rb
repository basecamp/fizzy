module User::Accessor
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :destroy
    has_many :collections, through: :accesses
    has_many :accessible_cards, through: :collections, source: :cards

    after_create_commit :grant_access_to_collections
  end

  private
    def grant_access_to_collections
      Access.insert_all account.collections.all_access.pluck(:id).collect { |collection_id| { collection_id: collection_id, user_id: id } }
    end
end
