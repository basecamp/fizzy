class Account::JoinCodesController < ApplicationController
  wrap_parameters :account_join_code, include: %i[ usage_limit ]

  before_action :set_join_code
  before_action :ensure_admin, only: %i[ update destroy ]

  def show
  end

  def edit
  end

  def update
    if @join_code.update(join_code_params)
      respond_to do |format|
        format.html { redirect_to account_join_code_path }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @join_code.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @join_code.reset

    respond_to do |format|
      format.html { redirect_to account_join_code_path }
      format.json { head :no_content }
    end
  end

  private
    def set_join_code
      @join_code = Current.account.join_code
    end

    def join_code_params
      params.expect account_join_code: [ :usage_limit ]
    end
end
