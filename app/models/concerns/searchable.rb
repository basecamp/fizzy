module Searchable
  extend ActiveSupport::Concern

  included do
    after_create_commit :create_in_search_index
    after_update_commit :update_in_search_index
    after_destroy_commit :remove_from_search_index
  end

  def reindex
    update_in_search_index
  end

  private
    def create_in_search_index
      Search::Record.for_account(account_id).create!(search_record_attributes)
    end

    def update_in_search_index
      Search::Record.for_account(account_id).upsert_all(
        [ search_record_attributes.merge(id: ActiveRecord::Type::Uuid.generate) ],
        update_only: [ :card_id, :board_id, :title, :content, :created_at ]
      )
    end

    def remove_from_search_index
      Search::Record.for_account(account_id).where(
        searchable_type: self.class.name,
        searchable_id: id
      ).delete_all
    end

    def search_record_attributes
      {
        account_id: account_id,
        searchable_type: self.class.name,
        searchable_id: id,
        card_id: search_card_id,
        board_id: search_board_id,
        title: Search::Stemmer.stem(search_title),
        content: Search::Stemmer.stem(search_content),
        created_at: created_at
      }
    end

  # Models must implement these methods:
  # - account_id: returns the account id
  # - search_title: returns title string or nil
  # - search_content: returns content string
  # - search_card_id: returns the card id (self.id for cards, card_id for comments)
  # - search_board_id: returns the board id
end
