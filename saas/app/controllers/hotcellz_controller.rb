# Two actions, because the two questions cost different things to answer.
#
# `show` is unauthenticated, like the /up beside it, so an alerting system holding no session can poll it.
# It asks the control socket only: describe and metrics are answered by the supervisor inline, with no fork
# and no queue, so no stranger can make this cell do work. It says `OK` or `FAIL` and nothing else — the
# status is the alertable signal, and the cell's inventory, counters and configuration are not a stranger's
# business.
#
# `test` crosses the work socket, which forks a worker per round trip. That is why it is staff-only: the
# gate is what bounds who may spend one.
#
# The trade this makes: only the round trips can see a work socket the app cannot use, and they now sit
# behind authentication — so a group or ownership mistake is not something a monitor will catch. It is a
# configuration error rather than something that degrades on its own, and finding it is a person running
# the checks, once, when the configuration changes.
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
