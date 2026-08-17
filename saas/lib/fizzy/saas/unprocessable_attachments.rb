module Fizzy
  module Saas
    # A permanent verdict from the cell is a fact about one variant of one blob. It must not fail the save of
    # the record that attached the file: `process: :immediately` transforms inline inside the record's
    # after_commit, so the record is already committed by then, and a raise there 500s a POST that succeeded.
    #
    # There are two immediate paths, and only one is a job. An already-uploaded blob (a direct-uploaded
    # embed) is varied by `CreateVariantsJob.perform_now`, so `discard_on` catches it — the same mechanism
    # the client gem uses to `retry_on` the transient class, and it fires under `perform_now`. A fresh io
    # (a form-uploaded avatar) is varied by `Attachment#uploaded` straight from the io, before the blob is
    # even stored, and no job is involved; a rescue there is what keeps the file uploaded and the save from
    # raising.
    #
    # The transient class is deliberately caught by neither: a saturated cell says nothing about the file,
    # and the client gem already retries it. Nothing is recorded against the blob either — one variant
    # failing says nothing about the others, and Rails will attempt the failed one again on next request,
    # which is the behaviour it had before the cell.
    #
    # Reported, because discarding is the one place a permanent verdict stops: elsewhere the raise reaches
    # Sentry on its own, and the perform.hot_cell subscriber reports nothing so as not to double it. On the
    # form path the rescue reports for the same reason.
    module UnprocessableAttachments
      # Rails' own loop, with the rescue inside it rather than around it: one variant failing must not skip
      # the rest, and the loop's last line marks the variants as processed — miss it and Rails re-runs every
      # one of them as a job after commit.
      module Attachment
        private
          def process_immediate_variants_from_io(io)
            return unless blob.variable?

            named_variants.each do |_variant_name, named_variant|
              next unless named_variant.process(record) == :immediately

              begin
                blob.variant(named_variant.transformations).process_from_io(io)
              rescue Cell::UnprocessableAttachment => error
                Rails.error.report error, handled: true, severity: :info
              end
              io.rewind if io.respond_to?(:rewind)
            end

            self.immediate_variants_processed = true
          end
      end

      def self.install!
        ActiveSupport.on_load(:active_storage_attachment) { prepend Attachment }

        %w[ ActiveStorage::CreateVariantsJob ActiveStorage::TransformJob ].each do |job|
          job.constantize.discard_on Cell::UnprocessableAttachment, report: true
        end
      end
    end
  end
end
