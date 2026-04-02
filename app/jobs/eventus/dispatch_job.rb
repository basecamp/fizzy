# frozen_string_literal: true

require "net/http"
require "uri"

module Eventus
  # Dispatches a Fizzy card_assigned event to the Eventus realtime ingestion
  # endpoint when the assignee is a bot user (i.e. an Eventus Legate).
  #
  # The endpoint processes the event synchronously and returns the processed
  # event ID, confirming that the Legate's WebSocket channel has been notified.
  #
  # Configuration:
  #   EVENTUS_REALTIME_URL — base URL of the Eventus instance
  #                          e.g. "http://eventus:3000"
  #
  # Retries three times with exponential back-off on transient errors. Silently
  # skips when EVENTUS_REALTIME_URL is not configured (dev/test environments
  # that do not run Eventus).
  class DispatchJob < ApplicationJob
    queue_as :default

    discard_on ActiveJob::DeserializationError

    ENDPOINT_PATH = "/events/fizzy/realtime"
    TIMEOUT = 10 # seconds

    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform(event)
      return unless eventus_configured?
      return unless event.action == "card_assigned"

      bot_assignees = load_bot_assignees(event)
      return if bot_assignees.empty?

      payload = build_payload(event, bot_assignees)
      post_to_eventus(payload)
    end

    private

    def eventus_configured?
      ENV["EVENTUS_REALTIME_URL"].present?
    end

    def load_bot_assignees(event)
      assignee_ids = event.particulars["assignee_ids"] || []
      User.bot.where(id: assignee_ids)
    end

    def build_payload(event, bot_assignees)
      card = event.card

      {
        event_type: "ticket.assigned",
        ticket: {
          id: card.id,
          title: card.title,
          assignee: {
            id: bot_assignees.first.id,
            name: bot_assignees.first.name,
            type: "bot"
          }
        },
        triggered_by: {
          name: event.creator.name,
          type: "user"
        }
      }.to_json
    end

    def post_to_eventus(payload)
      uri = URI.parse(ENV["EVENTUS_REALTIME_URL"] + ENDPOINT_PATH)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Post.new(uri.path, {
        "Content-Type" => "application/json",
        "User-Agent" => "fizzy/1.0.0 Eventus-Dispatch"
      })
      request.body = payload

      response = http.request(request)

      unless response.code.to_i.in?(200..299)
        raise "Eventus realtime dispatch failed: HTTP #{response.code} — #{response.body.truncate(200)}"
      end

      response
    end
  end
end
