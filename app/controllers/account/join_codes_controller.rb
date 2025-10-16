class Account::JoinCodesController < ApplicationController
  before_action :set_join_code, only: %i[ show edit update destroy ]

  def index
    @join_codes = Account::JoinCode.all
  end

  def show
  end

  def new
    @join_code = Account::JoinCode.new
  end

  def create
    @join_code = Account::JoinCode.new(join_code_params)

    if @join_code.save
      redirect_to account_join_code_path(@join_code)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @join_code.update(join_code_params)
      redirect_to account_join_code_path(@join_code)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @join_code.destroy
    redirect_to account_join_codes_path
  end

  private
    def set_join_code
      @join_code = Account::JoinCode.find(params[:id])
    end

    def join_code_params
      params.expect account_join_code: [ :usage_limit ]
    end
end
