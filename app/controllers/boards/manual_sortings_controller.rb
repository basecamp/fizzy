class Boards::ManualSortingsController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def create
    @board.update!(manual_sorting_enabled: true)
  end

  def destroy
    @board.update!(manual_sorting_enabled: false)
  end
end

