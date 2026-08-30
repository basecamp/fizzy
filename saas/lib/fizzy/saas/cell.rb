# The engine loads during Bundler.require, before it reaches these gems, so Gemfile order cannot be
# relied on to have defined HotCell by the time this file is read.
require "socket"
require "tmpdir"
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

      # A /hotcellz check that answered, but answered badly.
      class CheckFailed < StandardError; end

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

        # What /hotcellz reports. Every check answers rather than raises: the page's job is to be the last
        # step of booting an accessory, the moment a cell most likely cannot answer. Control socket only by
        # default; `work: true` is opt-in because each round trip takes a queue slot and forks a worker.
        # `at` and `host` are spelled the way the cell's own log lines spell them, so a reading lines up
        # against Loki.
        def diagnostics(work: false)
          checks = { describe: reporting { cell.describe or raise CheckFailed, "the cell did not answer; see metrics" },
                     metrics: reporting { answered cell.metrics } }

          checks.merge! echo: reporting { echo }, reopen: reporting { reopen } if work

          { at: Time.now.utc.iso8601(3), host: Socket.gethostname, root: root }.merge(checks)
        end

        # A fixed payload through example.echo, which reads the descriptor directly.
        def echo(message = "hotcell")
          round_trip Echo, message
        end

        # The same payload through example.reopen, which re-opens the input by name as every operation that
        # hands a tool a filename does — so a cell missing the shared group answers echo perfectly and
        # fails only this.
        def reopen(message = "hotcell")
          round_trip Reopen, message
        end

        private
          # The client verifies access modes, so the input must be "rb" and the output "wb";
          # Tempfile.create yields "r+", which it rejects.
          def round_trip(client, message)
            Dir.mktmpdir do |directory|
              source = File.join(directory, "in")
              destination = File.join(directory, "out")
              File.write source, message

              result = File.open(source, "rb") do |input|
                File.open(destination, "wb") { |output| client.perform_in_hotcell input, output }
              end

              verified result, File.read(destination), message
            end
          end

          # Staged means the worker read a copy rather than the caller's descriptor, so the round trip
          # proved nothing about the thing it exists to prove.
          def verified(result, returned, message)
            raise CheckFailed, "the cell returned #{returned.bytesize} bytes, not the #{message.bytesize} " \
                               "sent" unless returned == message
            raise CheckFailed, "the input was staged onto the worker's scratch, so this did not cross a " \
                               "descriptor" if result[:staged]

            result.merge(echoed: true)
          end

          # The registered cell answers enabled? rather than the module: a cell registered with an explicit
          # dir: is reachable whatever HOTCELL_ROOT says.
          def reporting
            if cell.enabled?
              { ok: true, result: yield }
            else
              { ok: false, error: "HOTCELL_ROOT is unset, so no cell is configured" }
            end
          rescue CheckFailed => error
            { ok: false, error: error.message }
          rescue => error
            { ok: false, error: "#{error.class}: #{error.message}" }
          end

          def answered(response)
            raise CheckFailed, "no answer from the control socket" if response.nil?
            raise CheckFailed, response.failure.to_s unless response.ok?

            response.result
          end
      end

      class Echo < ::HotCell::Client
        hotcell NAME
        operation "example.echo"
      end

      class Reopen < ::HotCell::Client
        hotcell NAME
        operation "example.reopen"
      end
    end
  end
end
