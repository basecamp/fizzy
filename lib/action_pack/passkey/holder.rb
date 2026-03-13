# Adds passkey support to an Active Record model (the "holder" of passkeys).
#
# == Usage
#
#   class User < ApplicationRecord
#     has_passkeys name: :email_address, display_name: :name
#   end
#
# This sets up a polymorphic +has_many :passkeys+ association and defines two methods on the
# model that supply holder-specific options for the WebAuthn ceremonies:
#
# - +passkey_creation_options+ — merged into ActionPack::Passkey.creation_options
# - +passkey_request_options+ — merged into ActionPack::Passkey.request_options
#
# == Options
#
# +has_passkeys+ accepts keyword arguments that map to WebAuthn creation or request option
# fields. Values can be symbols (sent to the record), procs (evaluated in the record's context),
# or plain values:
#
# [+name+]
#   A human-readable account identifier (typically an email or username) shown by the
#   authenticator when the user selects a passkey. Maps to the WebAuthn +user.name+ field.
#
# [+display_name+]
#   A friendly label for the user (typically their full name) shown by the authenticator
#   during passkey registration. Maps to the WebAuthn +user.displayName+ field.
#
#   has_passkeys name: :email, display_name: :name
#
# For more complex configuration, pass a block that receives a ActionPack::Passkey::Holder::Config:
#
#   has_passkeys do |config|
#     config.creation_options { { name: email, display_name: name } }
#     config.request_options  { { user_verification: "required" } }
#   end
module ActionPack::Passkey::Holder
  extend ActiveSupport::Concern

  class_methods do
    # Declares that this model can hold passkeys. Sets up a polymorphic +has_many+ association
    # and defines +passkey_creation_options+ and +passkey_request_options+ instance methods used
    # by ActionPack::Passkey to build ceremony options.
    #
    # Keyword arguments matching CreationOptions or RequestOptions fields are extracted and
    # turned into holder-scoped option procs automatically. An optional block yields a Config
    # for more complex setup.
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

  # Configuration object yielded by +has_passkeys+ when a block is given. Allows setting
  # custom association options and ceremony option blocks.
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

    # Sets a block to evaluate in the holder's context to produce additional request options.
    #
    #   config.request_options { { user_verification: "required" } }
    def request_options(&block)
      @request_options = block
    end

    # Sets a block to evaluate in the holder's context to produce additional creation options.
    #
    #   config.creation_options { { name: email, display_name: name } }
    def creation_options(&block)
      @creation_options = block
    end

    # Evaluates the request options block (if any) in the context of the given +record+. Called
    # internally by the +passkey_request_options+ method defined on the holder.
    def evaluate_request_options(record)
      if @request_options
        record.instance_exec(&@request_options)
      else
        {}
      end
    end

    # Evaluates the creation options block (if any) in the context of the given +record+. Called
    # internally by the +passkey_creation_options+ method defined on the holder.
    def evaluate_creation_options(record)
      if @creation_options
        record.instance_exec(&@creation_options)
      else
        {}
      end
    end

    private
      def extract_options_for(klass, options)
        keys = klass.attribute_names.map(&:to_sym)

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
