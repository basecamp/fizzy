module ActionPack::WebAuthn::Holder
  extend ActiveSupport::Concern

  class_methods do
    def has_passkeys(&block)
      config = Config.new
      block&.call(config)

      has_many config.association_name,
        as: :holder,
        dependent: config.dependent,
        class_name: "ActionPack::WebAuthn::Passkey"

      define_method(:passkey_creation_options) do
        {
          id: id,
          exclude_credentials: public_send(config.association_name)
        }.merge(config.evaluate(:creation_options, self))
      end

      define_method(:passkey_request_options) do
        { credentials: public_send(config.association_name) }.merge(config.evaluate(:request_options, self))
      end
    end
  end

  class Config
    attr_accessor :association_name, :dependent

    def initialize
      @association_name = :passkeys
      @dependent = :destroy
    end

    def request_options(&block)
      @request_options = block
    end

    def creation_options(&block)
      @creation_options = block
    end

    def evaluate(option, record)
      if (block = instance_variable_get(:"@#{option}"))
        record.instance_exec(&block)
      else
        {}
      end
    end
  end
end
