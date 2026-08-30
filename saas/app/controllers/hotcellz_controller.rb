# Two actions, because the two questions cost different things to answer. `show` is unauthenticated so a
# monitor can poll it, and asks only the control socket, which the supervisor answers inline with no fork.
# `test` crosses the work socket, which forks a worker per round trip — the staff gate bounds who may
# spend one. The trade: a broken work socket is invisible to a monitor, so a person runs `test` whenever
# the configuration changes.
class HotcellzController < ApplicationController
  allow_unauthenticated_access
  disallow_account_scope

  before_action :ensure_staff_access, only: :test

  def show
    reachable = healthy? Fizzy::Saas::Cell.diagnostics

    render plain: reachable ? "OK" : "FAIL", status: reachable ? :ok : :service_unavailable
  end

  def test
    diagnostics = Fizzy::Saas::Cell.diagnostics(work: true)

    render json: diagnostics, status: healthy?(diagnostics) ? :ok : :service_unavailable
  end

  private
    # Authorization#ensure_staff reads Current.identity.staff?, and this controller is reachable with no
    # identity at all. Signed out is refused rather than sent to a login page: a prober wants an answer.
    def ensure_staff_access
      head :forbidden unless Current.identity&.staff?
    end

    def healthy?(diagnostics)
      diagnostics.values_at(:describe, :metrics, :echo, :reopen).compact.all? { it[:ok] }
    end
end
