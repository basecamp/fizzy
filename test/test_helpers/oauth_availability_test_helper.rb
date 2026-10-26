module OauthAvailabilityTestHelper
  def with_oauth_availability(acceptance: true, issuance: true, pilot_client_ids: [], staff_only: false)
    config = Rails.application.config.x.oauth
    saved = config.to_h.slice(:acceptance_enabled, :issuance_enabled, :pilot_client_ids, :staff_only)

    config.acceptance_enabled = acceptance
    config.issuance_enabled = issuance
    config.pilot_client_ids = pilot_client_ids
    config.staff_only = staff_only
    yield
  ensure
    %i[ acceptance_enabled issuance_enabled pilot_client_ids staff_only ].each { |key| config[key] = saved[key] }
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
