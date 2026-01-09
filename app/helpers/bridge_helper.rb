module BridgeHelper
  def bridge_icon(name, extension = "svg")
    asset_url("#{name}.#{extension}")
  end
end
