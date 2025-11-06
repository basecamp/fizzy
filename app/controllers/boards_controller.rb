class BoardsController < ApplicationController
  include FilterScoped

  before_action :set_board, except: %i[ new create ]
  before_action :ensure_permission_to_change_accesses, only: %i[ update ]

  def show
    if @filter.used?(ignore_boards: true)
      show_filtered_cards
    else
      show_columns
    end
  end

  def new
    @board = Board.new
  end

  def create
    @board = Board.create! board_params.with_defaults(all_access: true)
    redirect_to board_path(@board)
  end

  def edit
    selected_user_ids = @board.users.pluck :id
    @selected_users, @unselected_users = \
      User.active.alphabetically.partition { |user| selected_user_ids.include? user.id }
  end

  def update
    @board.update! board_params
    @board.accesses.revise granted: grantees, revoked: revokees if grantees_changed?

    if @board.accessible_to?(Current.user)
      redirect_to edit_board_path(@board), notice: "Saved"
    else
      redirect_to root_path, notice: "Saved (you were removed from the board)"
    end
  end

  def destroy
    @board.destroy
    redirect_to root_path
  end

  private
    def set_board
      @board = Current.user.boards.find params[:id]
    end

    def ensure_permission_to_change_accesses
      if trying_to_change_accesses? && !Current.user.can_administer_board?(@board)
        head :forbidden
      end
    end

    def trying_to_change_accesses?
      all_access_changed? || grantees_changed?
    end

    def all_access_changed?
      params[:board]&.key?(:all_access)
    end

    def grantees_changed?
      params.key?(:user_ids)
    end

    def show_filtered_cards
      @filter.board_ids = [ @board.id ]
      set_page_and_extract_portion_from @filter.cards
    end

    def show_columns
      set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first
      fresh_when etag: [ @board, @page.records, @user_filtering ]
    end

    def board_params
      params.expect(board: [ :name, :all_access, :auto_postpone_period, :public_description ])
    end

    def grantees
      User.active.where id: grantee_ids
    end

    def revokees
      @board.users.where.not id: grantee_ids
    end

    def grantee_ids
      params.fetch :user_ids, []
    end
end
