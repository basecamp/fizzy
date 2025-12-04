class Integration::Basecamp::SetUpJob < ApplicationJob
  def perform(code:, state:)
    Integration::Basecamp.set_up(code: code, state: state)
  end
end
