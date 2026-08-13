# The engine loads during Bundler.require, before it reaches these gems, so Gemfile order cannot be
# relied on to have defined HotCell by the time this file is read.
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

      # Listed in the order Active Storage should see their classes, because the first analyzer or
      # previewer that accepts a blob is the one that runs.
      GROUPS = %i[ images pdfs media ]

      class << self
        def root
          ENV["HOTCELL_ROOT"].presence
        end

        def enabled?
          root.present?
        end

        # Registration happens even with no root, so a caller asking whether the cell is up gets an answer
        # rather than an UnregisteredCell, and the metrics collector has one shape to iterate.
        def register!
          ::HotCell.root = root
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

        # A fixed payload through example.echo, which is the only check that crosses the work socket —
        # describe and metrics both answer on the control socket, and a descriptor never crosses that.
        # The client verifies access modes, so the input must be "rb" and the output "wb"; Tempfile.create
        # yields "r+", which it rejects.
        def echo(message = "hotcell")
          Dir.mktmpdir do |directory|
            source = File.join(directory, "in")
            destination = File.join(directory, "out")
            File.write source, message

            result = File.open(source, "rb") do |input|
              File.open(destination, "wb") { |output| Echo.perform_in_hotcell input, output }
            end

            result.merge(echoed: File.read(destination) == message)
          end
        end

        private
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
    end
  end
end
