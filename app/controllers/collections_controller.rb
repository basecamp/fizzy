class CollectionsController < ApplicationController
  before_action :set_collection, except: %i[ new create ]

  def new
    @collection = Collection.new
  end

  def create
    @collection = Collection.create! collection_params.with_defaults(all_access: true)
    redirect_to cards_path(collection_ids: [ @collection ])
  end

  def edit
    selected_user_ids = @collection.users.pluck :id
    @selected_users, @unselected_users = User.active.alphabetically.partition { |user| selected_user_ids.include? user.id }
  end

  def update
    @collection.update! collection_params
    @collection.accesses.revise granted: grantees, revoked: revokees if grantees_changed?

    redirect_to edit_collection_path(@collection), notice: "Saved"
  end

  def destroy
    @collection.destroy
    redirect_to root_path
  end

  private
    def set_collection
      @collection = Current.user.collections.find params[:id]
    end

    def collection_params
      params.expect(collection: [ :name, :all_access, :auto_close_period, :auto_reconsider_period, :public_description ])
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
