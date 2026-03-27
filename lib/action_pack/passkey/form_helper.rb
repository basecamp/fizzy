# View helpers for rendering passkey web components.
#
# Include this module in your helper or ApplicationHelper to get access to:
#
# - +passkey_registration_button+ — render a <rails-passkey-registration-button> web component with
#   a form, hidden fields, and error messages for the registration ceremony.
# - +passkey_sign_in_button+ — render a <rails-passkey-sign-in-button> web component with
#   a form, hidden fields, and error messages for the authentication ceremony.
module ActionPack::Passkey::FormHelper
  REGISTRATION_ERROR_MESSAGE = "Something went wrong while registering your passkey."
  REGISTRATION_CANCELLED_MESSAGE = "Passkey registration was cancelled. Try again when you are ready."
  REGISTRATION_DUPLICATE_MESSAGE = "You already have a passkey registered on this device. Remove the existing one first to re-register."
  SIGN_IN_ERROR_MESSAGE = "Something went wrong while signing in with your passkey."
  SIGN_IN_CANCELLED_MESSAGE = "Passkey sign in was cancelled. Try again when you are ready."

  # Renders a +<rails-passkey-registration-button>+ web component containing a form with hidden
  # fields for the passkey registration ceremony and error messages. The form POSTs to +url+ and
  # includes hidden fields for +client_data_json+, +attestation_object+, and +transports+ —
  # populated by the web component after the browser credential API resolves.
  # Accepts a +label+ string or a block for button content.
  #
  # Options:
  # - +options+: WebAuthn creation options (JSON-serializable hash)
  # - +challenge_url+: endpoint to refresh the challenge nonce
  # - +form+: additional HTML attributes for the +<form>+ tag. Supports a +:param+ key
  #   to set the form parameter namespace (default: +:passkey+)
  # - +error+: HTML attributes for the error message +<div>+. Supports a +:message+ key
  #   to override the default error text
  # - +cancellation+: HTML attributes for the cancellation message +<div>+. Supports a
  #   +:message+ key to override the default cancellation text
  # - All other options are passed to the +<button>+ tag
  def passkey_registration_button(name = nil, url = nil, **options, &block)
    url, name = name, block ? capture(&block) : nil if block_given?
    component_options, form_options, button_options, error_options = partition_passkey_options(url, options)
    error_options[:error][:message] ||= REGISTRATION_ERROR_MESSAGE
    error_options[:cancellation][:message] ||= REGISTRATION_CANCELLED_MESSAGE
    error_options[:duplicate][:message] ||= REGISTRATION_DUPLICATE_MESSAGE
    param = form_options.delete(:param)

    content_tag("rails-passkey-registration-button", **component_options.transform_keys { |key| key.to_s.dasherize }) do
      tag.form(**form_options) do
        hidden_field_tag(:authenticity_token, form_authenticity_token) +
          hidden_field_tag("#{param}[client_data_json]", nil, id: nil, data: { passkey_field: "client_data_json" }) +
          hidden_field_tag("#{param}[attestation_object]", nil, id: nil, data: { passkey_field: "attestation_object" }) +
          hidden_field_tag("#{param}[transports][]", nil, id: nil, data: { passkey_field: "transports" }) +
          tag.button(name, type: :button, data: { passkey: "register" }, **button_options)
      end + passkey_error_messages(**error_options)
    end
  end

  # Renders a +<rails-passkey-sign-in-button>+ web component containing a form with hidden
  # fields for the passkey authentication ceremony and error messages. The form POSTs to +url+
  # and includes hidden fields for +id+, +client_data_json+, +authenticator_data+, and +signature+.
  # Accepts a +label+ string or a block for button content.
  #
  # Options:
  # - +options+: WebAuthn request options (JSON-serializable hash)
  # - +challenge_url+: endpoint to refresh the challenge nonce
  # - +mediation+: WebAuthn mediation hint (e.g. +"conditional"+ for autofill-assisted sign in)
  # - +form+: additional HTML attributes for the +<form>+ tag. Supports a +:param+ key
  #   to set the form parameter namespace (default: +:passkey+)
  # - +error+: HTML attributes for the error message +<div>+. Supports a +:message+ key
  #   to override the default error text
  # - +cancellation+: HTML attributes for the cancellation message +<div>+. Supports a
  #   +:message+ key to override the default cancellation text
  # - All other options are passed to the +<button>+ tag
  def passkey_sign_in_button(name = nil, url = nil, **options, &block)
    url, name = name, block ? capture(&block) : nil if block_given?
    component_options, form_options, button_options, error_options = partition_passkey_options(url, options)
    error_options[:error][:message] ||= SIGN_IN_ERROR_MESSAGE
    error_options[:cancellation][:message] ||= SIGN_IN_CANCELLED_MESSAGE
    param = form_options.delete(:param)

    content_tag("rails-passkey-sign-in-button", **component_options.transform_keys { |key| key.to_s.dasherize }) do
      tag.form(**form_options) do
        hidden_field_tag(:authenticity_token, form_authenticity_token) +
          hidden_field_tag("#{param}[id]", nil, id: nil, data: { passkey_field: "id" }) +
          hidden_field_tag("#{param}[client_data_json]", nil, id: nil, data: { passkey_field: "client_data_json" }) +
          hidden_field_tag("#{param}[authenticator_data]", nil, id: nil, data: { passkey_field: "authenticator_data" }) +
          hidden_field_tag("#{param}[signature]", nil, id: nil, data: { passkey_field: "signature" }) +
          tag.button(name, type: :button, data: { passkey: "sign_in" }, **button_options)
      end + passkey_error_messages(**error_options)
    end
  end

  private
    def partition_passkey_options(url, options)
      passkey_options = options.fetch(:options, {})

      component_options = options
        .slice(:challenge_url, :mediation)
        .reverse_merge(challenge_url: default_passkey_challenge_url, options: passkey_options.to_json(except: :challenge))
      form_options = options
        .fetch(:form, {})
        .reverse_merge(method: :post, action: url, class: "button_to", param: :passkey)
      error_options = options.slice(:error, :cancellation, :duplicate).reverse_merge(error: {}, cancellation: {}, duplicate: {})

      button_options = options.except(:options, :form, *component_options.keys, *error_options.keys)

      [ component_options, form_options, button_options, error_options ]
    end

    def default_passkey_challenge_url
      if challenge_url = Rails.configuration.action_pack.passkey.challenge_url
        instance_exec(&challenge_url)
      else
        passkey_challenge_path
      end
    end

    def passkey_error_messages(error: {}, cancellation: {}, duplicate: {})
      error_message = error[:message]
      error_attributes = error.except(:message)
      error_attributes[:data] ||= {}
      error_attributes[:data][:passkey_error] = "error"

      cancellation_message = cancellation[:message]
      cancellation_attributes = cancellation.except(:message)
      cancellation_attributes[:data] ||= {}
      cancellation_attributes[:data][:passkey_error] = "cancelled"

      messages = tag.div(error_message, hidden: true, **error_attributes) +
        tag.div(cancellation_message, hidden: true, **cancellation_attributes)

      if duplicate[:message]
        duplicate_attributes = duplicate.except(:message)
        duplicate_attributes[:data] = { passkey_error: "duplicate" }
        messages += tag.div(duplicate[:message], hidden: true, **duplicate_attributes)
      end

      messages
    end
end
