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
    # Deliberately not named HotCell, or any near-spelling of it: a cell is forked from a process that may
    # have loaded the client, and a shared constant across the two sides is a superclass mismatch at boot.
    #
    # Two switches, because a cell being reachable and a cell taking traffic are different questions.
    # HOTCELL_ROOT registers the cell, so metrics, describe, the healthcheck and /hotcellz all answer while
    # every conversion still runs in the app. HOTCELL_ACTIVE_STORAGE is what moves the work, and it is a
    # list rather than a flag because the rollout moves operations in groups.
    module Cell
      NAME = "active_storage"

      # A cell may wait queue_wait in the queue and then run for deadline before it gets to say what
      # happened. Below its answer_within, a saturated cell arrives here as a transport failure rather than
      # as its own verdict, and the client warns about it at every boot.
      TIMEOUT = 135

      # An input this cell will never decode, which is a verdict about one file and may be recorded
      # against it.
      class UnprocessableAttachment < StandardError; end

      # Everything uncertain: a saturated cell, a restarting accessory, a deadline. Must not descend from
      # UnprocessableAttachment — the gem raises ConfigurationError if it does, because the inheritance
      # graph is the classification and every retryable failure would be written down as permanent.
      class ProcessingUnavailable < StandardError; end

      # A /hotcellz check that answered, but answered badly. Its message is already a sentence, so it is
      # reported without an exception class in front of it.
      class CheckFailed < StandardError; end

      # Listed in the order Active Storage should see their classes, because the first analyzer or
      # previewer that accepts a blob is the one that runs.
      GROUPS = %i[ images pdfs media ]

      class << self
        def root
          ENV["HOTCELL_ROOT"].presence
        end

        # Unset in development, where the app and its cell run as one user and there is no group to share.
        # Integer() rather than to_i, because a group name or a typo is 0 under to_i — root — and the
        # client would chown every descriptor to it.
        def group
          value = ENV["HOTCELL_GROUP"].presence
          return nil if value.nil?

          Integer(value)
        rescue ArgumentError
          raise ArgumentError, "HOTCELL_GROUP must be a gid, not #{value.inspect}"
        end

        def enabled?
          root.present?
        end

        # Registration happens even with no root, so a caller asking whether the cell is up gets an answer
        # rather than an UnregisteredCell, and the metrics collector has one shape to iterate.
        def register!
          ::HotCell.root = root
          ::HotCell.group = group
          ::HotCell.register NAME, timeout: TIMEOUT,
            permanent: UnprocessableAttachment, transient: ProcessingUnavailable
        end

        def cell
          ::HotCell.cell NAME
        end

        def processing_attachments?
          enabled? && groups.any?
        end

        def processing?(group)
          processing_attachments? && groups.include?(group)
        end

        # Everything Active Storage should be configured with. `analyzers` and `previewers` are arrays
        # Rails replaces wholesale, so a group that is off has to contribute Rails' own classes back or a
        # partial rollout would not stage the work — it would delete it. Step two hands Rails a mixed
        # array: this cell's PDF previewer beside Rails' own video one. That works only while the app
        # image still carries the tools Rails' built-ins shell out to, which is why they leave last.
        def active_storage_configuration
          return {} unless processing_attachments?

          GROUPS.each_with_object({ analyzers: [], previewers: [] }) do |group, merged|
            configuration = configuration_for(group, moved: processing?(group))

            merged[:variant_processor] = configuration[:variant_processor] if configuration.key?(:variant_processor)
            merged[:analyzers] += configuration.fetch(:analyzers, [])
            merged[:previewers] += configuration.fetch(:previewers, [])
          end
        end

        # What /hotcellz reports. Every check answers rather than raises, because the page's job is to be
        # the last step of booting an accessory — the moment when a cell most likely cannot answer.
        #
        # describe and metrics ask the control socket, and a descriptor never crosses that, so both answer
        # happily for a cell whose work socket the app cannot use at all. The echo round trip is the only
        # one of the three that says anything about the socket real files travel over. The volume-ownership
        # mistakes fail as EACCES on the first real request, and nothing else here would say so.
        # Neither control call raises for itself: describe returns nil after warning, and metrics returns a
        # response that is simply not ok. Reported as they come back, both say "ok" with an empty result
        # for a cell that never answered — the same shape as a healthy one.
        # `at` is spelled the way the cell spells it in its own log lines — same key, same UTC ISO8601 with
        # milliseconds — so a reading taken here lines up mechanically against the cell's logs in Loki.
        # `host` because every answer here is about one host's cell: a cell's sockets are host-local, a poll
        # through the load balancer lands on whichever host it lands on, and an answer that does not say
        # which one cannot be acted on. Kamal boots a container with the deploy host and a random suffix as
        # its hostname, so this names the machine and the container on it.
        # Control socket only by default, which the supervisor answers inline with no fork and no queue.
        # `work: true` is opt-in because it puts a request on the cell's queue and forks a worker for each
        # round trip: the caller that wants to spend that has to say so.
        def diagnostics(work: false)
          checks = { describe: reporting { cell.describe or raise CheckFailed, "the cell did not answer; see metrics" },
                     metrics: reporting { answered cell.metrics } }

          checks.merge! echo: reporting { echo }, reopen: reporting { reopen } if work

          { at: Time.now.utc.iso8601(3), host: Socket.gethostname,
            root: root, groups: processing_attachments? ? groups : [] }.merge(checks)
        end

        # A fixed payload through example.echo, which reads the descriptor directly.
        def echo(message = "hotcell")
          round_trip Echo, message
        end

        # The same payload through example.reopen, which reads the input by name. `/dev/fd/N` is a fresh
        # open, rechecked against the cell's uid and the file's mode, so this succeeds only where the two
        # sides share a group. Every operation that hands a tool a filename does exactly this, and echo
        # never does — so a cell missing the group answers echo perfectly and fails every real conversion.
        def reopen(message = "hotcell")
          round_trip Reopen, message
        end

        private
          # The checks that cross the work socket. describe and metrics both answer on the control socket,
          # and a descriptor never crosses that.
          #
          # Both verdicts raise rather than being reported beside an `ok`, because a caller reads the
          # status and not the body: a cell that answers with the wrong bytes is not a healthy cell, and
          # reporting `echoed: false` under `ok: true` is a 200 for a broken one.
          #
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

          # Staged means the worker read a copy on its own scratch rather than the caller's file, so the
          # round trip proved nothing about the descriptor it exists to prove.
          def verified(result, returned, message)
            raise CheckFailed, "the cell returned #{returned.bytesize} bytes, not the #{message.bytesize} " \
                               "sent" unless returned == message
            raise CheckFailed, "the input was staged onto the worker's scratch, so this did not cross a " \
                               "descriptor" if result[:staged]

            result.merge(echoed: true)
          end

          # The registered cell answers this rather than the module, because a cell registered with an
          # explicit dir: is reachable whatever HOTCELL_ROOT says.
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

          # What each group installs when it has moved, and what Rails runs when it has not. The constants
          # resolve here rather than in a table at load time, because this file is required during
          # Bundler.require, before Active Storage has defined its own.
          def configuration_for(group, moved:)
            case [ group, moved ]
            in [ :images, true ]
              # Rails' image analyzers answer accept? with `variant_processor == :vips` (or
              # :mini_magick), so pointing the transformer at a class makes both decline and blobs get
              # marked analyzed with no dimensions. The two move together or not at all.
              { variant_processor: ActiveStorage::HotCell::Client::Transformers::Image::Vips,
                analyzers: [ ActiveStorage::HotCell::Client::Analyzers::Image::Vips ] }
            in [ :images, false ]
              { analyzers: [ ActiveStorage::Analyzer::ImageAnalyzer::Vips,
                             ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick ] }
            in [ :pdfs, true ]
              { previewers: [ ActiveStorage::HotCell::Client::Previewers::Pdf::Mutool ] }
            in [ :pdfs, false ]
              { previewers: [ ActiveStorage::Previewer::PopplerPDFPreviewer,
                              ActiveStorage::Previewer::MuPDFPreviewer ] }
            in [ :media, true ]
              { analyzers: [ ActiveStorage::HotCell::Client::Analyzers::Video::FFprobe,
                             ActiveStorage::HotCell::Client::Analyzers::Audio::FFprobe ],
                previewers: [ ActiveStorage::HotCell::Client::Previewers::Video::FFmpeg ] }
            in [ :media, false ]
              { analyzers: [ ActiveStorage::Analyzer::VideoAnalyzer,
                             ActiveStorage::Analyzer::AudioAnalyzer ],
                previewers: [ ActiveStorage::Previewer::VideoPreviewer ] }
            end
          end

          # An unrecognized name raises rather than meaning "off": a typo in a deploy file would otherwise
          # be a rollout that appears to have happened.
          def groups
            names = ENV["HOTCELL_ACTIVE_STORAGE"].to_s.split(",").filter_map { it.strip.downcase.presence&.to_sym }
            return GROUPS if names.include?(:all)

            names.each do |name|
              unless GROUPS.include?(name)
                raise ArgumentError, "unknown HOTCELL_ACTIVE_STORAGE group #{name.inspect} " \
                                     "(known: #{GROUPS.join(", ")}, all)"
              end
            end

            names
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
