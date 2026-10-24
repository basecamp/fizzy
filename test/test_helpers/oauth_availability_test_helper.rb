module OauthAvailabilityTestHelper
  def with_oauth_availability(acceptance: true, issuance: true, pilot_client_ids: [])
    config = Rails.application.config.x.oauth
    saved = config.to_h.slice(:acceptance_enabled, :issuance_enabled, :pilot_client_ids)

    config.acceptance_enabled = acceptance
    config.issuance_enabled = issuance
    config.pilot_client_ids = pilot_client_ids
    yield
  ensure
    %i[ acceptance_enabled issuance_enabled pilot_client_ids ].each { |key| config[key] = saved[key] }
  end
end
