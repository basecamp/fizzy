# Staff-only, unlike the /up beside it: this names the tools in the cell's image and reports its limits.
class HotcellzController < AdminController
  layout "public"

  def show
    @diagnostics = Fizzy::Saas::Cell.diagnostics
  end
end
