# The engine loads during Bundler.require, before it reaches these gems, so Gemfile order cannot be
# relied on to have defined HotCell by the time this file is read.
require "hot_cell/client"
require "active_storage/hot_cell/client"

module Fizzy
  module Saas
    # Attachment processing in an unprivileged sibling container.
    #
    # One switch: HOTCELL_ROOT registers the cell, which then carries every conversion. Only development
    # and test may run without one; everything then runs in the app.
    module Cell
      NAME = "active_storage"

      # Must cover the cell's answer_within (queue_wait + deadline + reply), or a saturated cell arrives
      # as a transport failure rather than its own verdict.
      TIMEOUT = 135

      # A verdict about one file, which may be recorded against it.
      class UnprocessableAttachment < StandardError; end

      # Everything uncertain: a saturated cell, a restarting accessory, a deadline. Must not descend from
      # UnprocessableAttachment — the inheritance graph is the classification.
      class ProcessingUnavailable < StandardError; end

      class << self
        # SECRET_KEY_BASE_DUMMY is asset precompilation in the Dockerfile, which boots the production
        # environment with no cell.
        def root
          value = ENV["HOTCELL_ROOT"].presence

          if value.nil? && !Rails.env.local? && !ENV["SECRET_KEY_BASE_DUMMY"]
            raise ::HotCell::ConfigurationError, "HOTCELL_ROOT must be set outside development and test"
          end

          value
        end

        # Unset in development, where the app and its cell run as one user. The gem's setter coerces and
        # raises for a value that is not a numeric gid.
        def group
          ENV["HOTCELL_GROUP"].presence
        end

        def enabled?
          root.present?
        end

        # Registration happens even with no root, so callers get an answer rather than an UnregisteredCell.
        def register!
          ::HotCell.root = root
          ::HotCell.group = group
          ::HotCell.register NAME, timeout: TIMEOUT,
            permanent: UnprocessableAttachment, transient: ProcessingUnavailable
        end

        def cell
          ::HotCell.cell NAME
        end

        # Resolved at call time because this file is required during Bundler.require, before Active
        # Storage has defined its own classes.
        def active_storage_configuration
          return {} unless enabled?

          { variant_processor: ActiveStorage::HotCell::Client::Transformers::Image::Vips,
            analyzers: [ ActiveStorage::HotCell::Client::Analyzers::Image::Vips,
                         ActiveStorage::HotCell::Client::Analyzers::Video::FFprobe,
                         ActiveStorage::HotCell::Client::Analyzers::Audio::FFprobe ],
            previewers: [ ActiveStorage::HotCell::Client::Previewers::Pdf::Mutool,
                          ActiveStorage::HotCell::Client::Previewers::Video::FFmpeg ] }
        end
      end
    end
  end
end
