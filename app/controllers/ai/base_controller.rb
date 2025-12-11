module AI
  class BaseController < ApplicationController
    skip_before_action :require_account

    private
      # Synchronous generation helper for non-streaming requests
      def render_generation(agent)
        response = agent.generate_now
        render json: { content: response.message.content }
      rescue ActiveAgent::GenerationProvider::GenerationProviderError => e
        Rails.logger.error "[AI::BaseController] Generation error: #{e.message}"
        render json: { error: e.message }, status: :unprocessable_entity
      rescue => e
        Rails.logger.error "[AI::BaseController] Unexpected error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # Async streaming generation helper
      def render_streaming(agent, stream_id:)
        agent.generate_later
        render json: { stream_id: stream_id }
      rescue => e
        Rails.logger.error "[AI::BaseController] Streaming error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: e.message }, status: :unprocessable_entity
      end
  end
end
