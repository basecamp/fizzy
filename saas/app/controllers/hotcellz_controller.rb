# Staff-only, unlike the /up beside it: this names the tools in the cell's image and reports its limits.
#
# JSON with no layout, because this gets read from a terminal during a rollout as often as from a browser,
# and the answer is a data structure rather than a page.
class HotcellzController < AdminController
  def show
    render json: Fizzy::Saas::Cell.diagnostics
  end
end
