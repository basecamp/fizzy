# View helpers for rendering passkey forms and meta tags.
#
# Include this module in your helper or ApplicationHelper to get access to:
#
# - +passkey_creation_options_meta_tag+ / +passkey_request_options_meta_tag+ — render a <meta>
#   tag containing the JSON-serialized WebAuthn options for the browser credential API.
# - +passkey_creation_button+ — render a form with hidden fields for the registration ceremony.
# - +passkey_sign_in_button+ — render a form with hidden fields for the authentication
#   ceremony.
module ActionPack::Passkey::FormHelper
  # Renders +<meta>+ tags containing JSON-serialized creation options and the challenge endpoint
  # URL for the WebAuthn registration ceremony. The companion JavaScript reads these tags to call
  # +navigator.credentials.create()+.
  def passkey_creation_options_meta_tag(creation_options, challenge_url: nil)
    passkey_challenge_url_meta_tag(challenge_url: challenge_url) +
      tag.meta(name: "passkey-creation-options", content: creation_options.to_json)
  end

  # Renders +<meta>+ tags containing JSON-serialized request options and the challenge endpoint
  # URL for the WebAuthn authentication ceremony. The companion JavaScript reads these tags to
  # call +navigator.credentials.get()+.
  def passkey_request_options_meta_tag(request_options, challenge_url: nil)
    passkey_challenge_url_meta_tag(challenge_url: challenge_url) +
      tag.meta(name: "passkey-request-options", content: request_options.to_json)
  end

  # Renders a form with hidden fields for the passkey registration ceremony. The form POSTs to
  # +url+ and includes hidden fields for +client_data_json+, +attestation_object+, and
  # +transports+ — populated by the Stimulus controller after the browser credential API
  # resolves. Accepts a +label+ string or a block for button content.
  #
  # Options:
  # - +param+: the form parameter namespace (default: +:passkey+)
  # - +form+: additional HTML attributes for the +<form>+ tag
  # - All other options are passed to the +<button>+ tag
  def passkey_creation_button(name = nil, url = nil, param: :passkey, form: {}, **options, &block)
    url, name = name, block ? capture(&block) : nil if block_given?
    form_options = form.reverse_merge(method: :post, action: url, class: "button_to")

    tag.form(**form_options) do
      hidden_field_tag(:authenticity_token, form_authenticity_token) +
        hidden_field_tag("#{param}[client_data_json]", nil, id: nil, data: { passkey_field: "client_data_json" }) +
        hidden_field_tag("#{param}[attestation_object]", nil, id: nil, data: { passkey_field: "attestation_object" }) +
        hidden_field_tag("#{param}[transports][]", nil, id: nil, data: { passkey_field: "transports" }) +
        tag.button(name, type: :button, data: { passkey: "create" }, **options)
    end
  end

  # Renders a form with hidden fields for the passkey authentication ceremony. The form POSTs to
  # +url+ and includes hidden fields for +id+, +client_data_json+, +authenticator_data+, and
  # +signature+
  # Accepts a +label+ string or a block for button content.
  #
  # Options:
  # - +param+: the form parameter namespace (default: +:passkey+)
  # - +mediation+: WebAuthn mediation hint (e.g. +"conditional"+ for autofill-assisted sign in)
  # - +form+: additional HTML attributes for the +<form>+ tag
  # - All other options are passed to the +<button>+ tag
  def passkey_sign_in_button(name = nil, url = nil, param: :passkey, mediation: nil, form: {}, **options, &block)
    url, name = name, block ? capture(&block) : nil if block_given?
    form_data = {}
    form_data[:passkey_mediation] = mediation if mediation
    form_options = form.reverse_merge(method: :post, action: url, class: "button_to", data: form_data)

    tag.form(**form_options) do
      hidden_field_tag(:authenticity_token, form_authenticity_token) +
        hidden_field_tag("#{param}[id]", nil, id: nil, data: { passkey_field: "id" }) +
        hidden_field_tag("#{param}[client_data_json]", nil, id: nil, data: { passkey_field: "client_data_json" }) +
        hidden_field_tag("#{param}[authenticator_data]", nil, id: nil, data: { passkey_field: "authenticator_data" }) +
        hidden_field_tag("#{param}[signature]", nil, id: nil, data: { passkey_field: "signature" }) +
        tag.button(name, type: :button, data: { passkey: "sign_in" }, **options)
    end
  end

  private
    def passkey_challenge_url_meta_tag(challenge_url: nil)
      tag.meta(name: "passkey-challenge-url", content: challenge_url || default_passkey_challenge_url)
    end

    def default_passkey_challenge_url
      if challenge_url = Rails.configuration.action_pack.passkey.challenge_url
        instance_exec(&challenge_url)
      else
        passkey_challenge_path
      end
    end
end
