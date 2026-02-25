module FormsHelper
  def auto_submit_form_with(**attributes, &)
    data = attributes.delete(:data) || {}
    data[:controller] = "auto-submit #{data[:controller]}".strip

    if block_given?
      form_with **attributes, data: data, &
    else
      form_with(**attributes, data: data) { }
    end
  end

  def bridged_form_with(**attributes, &)
    data = attributes.delete(:data) || {}
    controllers = [ data[:controller], "bridge--form" ].compact.join(" ").strip
    actions = [
      data[:action],
      "turbo:submit-start->bridge--form#submitStart",
      "turbo:submit-end->bridge--form#submitEnd"
    ].compact.join(" ").strip

    data[:controller] = controllers
    data[:action] = actions

    if block_given?
      form_with **attributes, data: data, &
    else
      form_with(**attributes, data: data) { }
    end
  end
end
