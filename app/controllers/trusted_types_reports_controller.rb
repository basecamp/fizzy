# Receives the Trusted Types report-only pilot's violation reports and logs only
# what the sink inventory needs: the sink, the script location that wrote to it,
# and the route of the page. See TrustedTypesViolation for what's dropped.
class TrustedTypesReportsController < ApplicationController
  MAX_REPORT_SIZE = 16.kilobytes

  disallow_account_scope
  allow_unauthenticated_access
  skip_forgery_protection

  rate_limit to: 60, within: 1.minute, with: -> { head :too_many_requests }

  def create
    if violation = TrustedTypesViolation.parse(request.body.read(MAX_REPORT_SIZE))
      logger.info violation.to_s
    end

    head :no_content
  end
end
