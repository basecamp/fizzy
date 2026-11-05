module OauthAvailabilityTestHelper
  AVAILABILITY_KEYS = %i[ acceptance_enabled issuance_enabled pilot_client_ids connected_apps_preview connected_apps_preview_reviewer_ids ]

  def with_oauth_availability(acceptance: true, issuance: true, pilot_client_ids: [], preview: false, reviewer_ids: [])
    config = Rails.application.config.x.oauth
    saved = config.to_h.slice(*AVAILABILITY_KEYS)

    config.acceptance_enabled = acceptance
    config.issuance_enabled = issuance
    config.pilot_client_ids = pilot_client_ids
    config.connected_apps_preview = preview
    config.connected_apps_preview_reviewer_ids = reviewer_ids
    yield
  ensure
    AVAILABILITY_KEYS.each { |key| config[key] = saved[key] }
  end

  def with_dcr_allowed_https_hosts(*hosts)
    config = Rails.application.config.x.oauth
    saved = config.dcr_allowed_https_hosts

    config.dcr_allowed_https_hosts = hosts
    yield
  ensure
    config.dcr_allowed_https_hosts = saved
  end
end
