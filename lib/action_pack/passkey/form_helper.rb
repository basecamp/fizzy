module ActionPack::Passkey::FormHelper
  def passkey_creation_options_meta_tag(creation_options)
    tag.meta(name: "passkey-creation-options", content: creation_options.to_json)
  end

  def create_passkey_button(label = nil, url, param: :passkey, form: {}, **options, &block)
    button_content = block ? capture(&block) : label
    form_options = form.reverse_merge(method: :post, action: url, class: "button_to")

    tag.form(**form_options) do
      safe_join([
        hidden_field_tag(:authenticity_token, form_authenticity_token),
        hidden_field_tag("#{param}[client_data_json]", nil, id: nil, data: { passkey_field: "client_data_json" }),
        hidden_field_tag("#{param}[attestation_object]", nil, id: nil, data: { passkey_field: "attestation_object" }),
        hidden_field_tag("#{param}[transports][]", nil, id: nil, data: { passkey_field: "transports" }),
        tag.button(button_content, type: :button, data: { passkey: "create" }, **options)
      ])
    end
  end
end
