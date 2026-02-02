class BoardsController < ApplicationController
  include FilterScoped

  before_action :set_board, except: %i[ index new create ]
  before_action :ensure_permission_to_admin_board, only: %i[ update destroy ]

  def index
    set_page_and_extract_portion_from Current.user.boards
  end

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

    respond_to do |format|
      format.html { redirect_to board_path(@board) }
      format.json { head :created, location: board_path(@board, format: :json) }
    end
  end

  def edit
    selected_user_ids = @board.users.ids
    @selected_users, @unselected_users = \
      @board.account.users.active.alphabetically.includes(:identity).partition { |user| selected_user_ids.include? user.id }
  end

  def update
    @board.update! board_params
    @board.accesses.revise granted: grantees, revoked: revokees if grantees_changed?

    respond_to do |format|
      format.html do
        if @board.accessible_to?(Current.user)
          redirect_to edit_board_path(@board), notice: "Saved"
        else
          redirect_to root_path, notice: "Saved (you were removed from the board)"
        end
      end
      format.json { head :no_content }
    end
  end

  def destroy
    @board.destroy

    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { head :no_content }
    end
  end

  private
    def set_board
      @board = Current.user.boards.find params[:id]
    end

    def ensure_permission_to_admin_board
      unless Current.user.can_administer_board?(@board)
        head :forbidden
      end
    end

    def grantees_changed?
      params.key?(:user_ids)
    end

    def show_filtered_cards
      @filter.board_ids = [ @board.id ]
      set_page_and_extract_portion_from @filter.cards
    end

    def show_columns
      cards = @board.cards.awaiting_triage.latest.with_golden_first.preloaded
      set_page_and_extract_portion_from cards
      fresh_when etag: [ @board, @page.records, @user_filtering, Current.account ]
    end

    def board_params
      params.expect(board: [ :name, :all_access, :auto_postpone_period, :public_description ])
    end

    def grantees
      @board.account.users.active.where id: grantee_ids
    end

    def revokees
      @board.users.where.not id: grantee_ids
    end

    def grantee_ids
      params.fetch :user_ids, []
    end
end
