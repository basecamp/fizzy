class Cards::StepsController < ApplicationController
  include CardScoped

  before_action :set_step, only: %i[ show edit update destroy ]

  def create
    @step = @card.steps.create!(step_params)
  end

  def show
  end

  def edit
  end

  def update
    @step.update!(step_params)
  end

  def destroy
    @step.destroy!
  end

  private
    def set_step
      @step = @card.steps.find(params[:id])
    end

    def step_params
      params.expect(step: [ :content, :completed ])
    end
end
