module ActionPack::Passkey::Holder
  extend ActiveSupport::Concern

  class_methods do
    def has_passkeys(**options, &block)
      config = Config.new(**options)
      block&.call(config)

      has_many config.association_name,
        as: :holder,
        dependent: config.dependent,
        class_name: "ActionPack::Passkey"

      define_method(:passkey_creation_options) do
        {
          id: id,
          exclude_credentials: public_send(config.association_name)
        }.merge(config.evaluate_creation_options(self))
      end

      define_method(:passkey_request_options) do
        { credentials: public_send(config.association_name) }.merge(config.evaluate_request_options(self))
      end
    end
  end

  class Config
    attr_accessor :association_name, :dependent

    def initialize(**options)
      @association_name = options.delete(:association_name) || :passkeys
      @dependent = options.delete(:dependent) || :destroy

      if creation_opts = extract_options_for(ActionPack::WebAuthn::PublicKeyCredential::CreationOptions, options)
        @creation_options = options_to_proc(creation_opts)
      end

      if request_opts = extract_options_for(ActionPack::WebAuthn::PublicKeyCredential::RequestOptions, options)
        @request_options = options_to_proc(request_opts)
      end
    end

    def request_options(&block)
      @request_options = block
    end

    def creation_options(&block)
      @creation_options = block
    end

    def evaluate_request_options(record)
      record.instance_exec(&@request_options) if @request_options
    end

    def evaluate_creation_options(record)
      record.instance_exec(&@creation_options) if @creation_options
    end

    private
      def extract_options_for(klass, options)
        keys = klass.instance_method(:initialize).parameters.filter_map do |type, name|
          name if type == :key || type == :keyreq
        end

        extracted = options.slice(*keys)
        options.except!(*keys)
        extracted if extracted.any?
      end

      def options_to_proc(options)
        proc do
          options.transform_values do |value|
            case value
            when Symbol then send(value)
            when Proc then instance_exec(&value)
            else value
            end
          end
        end
      end
  end
end
