class CollectionsController < ApplicationController
  include FilterScoped

  before_action :set_collection, except: %i[ new create ]

  def show
    if @filter.used?(ignore_collections: true)
      show_filtered_cards
    else
      show_columns
    end
  end

  def new
    @collection = Collection.new
  end

  def create
    @collection = Collection.create! collection_params.with_defaults(all_access: true)
    redirect_to collection_path(@collection)
  end

  def edit
    selected_user_ids = @collection.users.pluck :id
    @selected_users, @unselected_users = \
      User.active.alphabetically.partition { |user| selected_user_ids.include? user.id }
  end

  def update
    @collection.update! collection_params
    @collection.accesses.revise granted: grantees, revoked: revokees if grantees_changed?

    if @collection.accessible_to?(Current.user)
      redirect_to edit_collection_path(@collection), notice: "Saved"
    else
      redirect_to root_path, notice: "Saved (you were removed from the collection)"
    end
  end

  def destroy
    @collection.destroy
    redirect_to root_path
  end

  private
    def set_collection
      @collection = Current.user.collections.find params[:id]
    end

    def show_filtered_cards
      @filter.collection_ids = [ @collection.id ]
      set_page_and_extract_portion_from @filter.cards
    end

    def show_columns
      set_page_and_extract_portion_from @collection.cards.awaiting_triage.latest.with_golden_first
      fresh_when etag: [ @collection, @page.records, @user_filtering ]
    end

    def collection_params
      params.expect(collection: [ :name, :all_access, :auto_postpone_period, :public_description ])
    end

    def grantees
      User.active.where id: grantee_ids
    end

    def revokees
      @collection.users.where.not id: grantee_ids
    end

    def grantee_ids
      params.fetch :user_ids, []
    end

    def grantees_changed?
      params.key?(:user_ids)
    end
end
