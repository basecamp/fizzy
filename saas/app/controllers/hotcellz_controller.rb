# Unauthenticated, like the /up beside it, so a monitor can poll it — an alerting system holds no staff
# session. The status code is the alertable signal and the body is the diagnosis: 503 when any check
# fails, so a plain HTTP check is enough and nobody has to parse JSON to raise an alarm.
#
# This does publish the cell's inventory and its limits. That is the trade for being able to alert on it.
class HotcellzController < ApplicationController
  allow_unauthenticated_access
  disallow_account_scope

  def show
    diagnostics = Fizzy::Saas::Cell.diagnostics

    render json: diagnostics, status: healthy?(diagnostics) ? :ok : :service_unavailable
  end

  private
    def healthy?(diagnostics)
      diagnostics.values_at(:describe, :metrics, :echo, :reopen).all? { it[:ok] }
    end
end
