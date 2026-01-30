class ZipFile
  class << self
    def create_for(attachment, filename:)
      raise ArgumentError, "No block given" unless block_given?

      reflection = attachment.record.class.reflect_on_attachment(attachment.name)
      service_name = reflection.options[:service_name] || ActiveStorage::Blob.service.name
      service = ActiveStorage::Blob.services.fetch(service_name)

      if s3_service?(service)
        create_for_s3(attachment, filename: filename, service: service) { |zip| yield zip }
      else
        create_for_disk(attachment, filename: filename) { |zip| yield zip }
      end
    end

    def read_from(blob)
      raise ArgumentError, "No block given" unless block_given?

      if s3_service?(blob.service)
        read_from_s3(blob) { |zip| yield zip }
      else
        read_from_disk(blob) { |zip| yield zip }
      end
    end

    private
      def s3_service?(service)
        # The S3 service doesn't get loaded in development unless it's used
        defined?(ActiveStorage::Service::S3Service) && service.is_a?(ActiveStorage::Service::S3Service)
      end

      def create_for_s3(attachment, filename:, service:)
        blob = ActiveStorage::Blob.create_before_direct_upload!(
          filename: filename,
          content_type: "application/zip",
          byte_size: 0,
          checksum: "pending"
        )

        writer = Writer.new
        service.upload(blob.key, writer.io) do |io|
          writer.stream_to(io)
          yield writer
        end

        blob.update!(byte_size: writer.byte_size, checksum: writer.checksum)
        attachment.attach(blob)
      end

      def create_for_disk(attachment, filename:)
        tempfile = Tempfile.new([ "export", ".zip" ])
        tempfile.binmode

        writer = Writer.new(tempfile)
        yield writer
        writer.close

        tempfile.rewind
        attachment.attach(io: tempfile, filename: filename, content_type: "application/zip")
      ensure
        tempfile&.close
        tempfile&.unlink
      end

      def read_from_s3(blob)
        url = blob.url(expires_in: 6.hour)
        remote_io = ZipKit::RemoteIO.new(url)
        reader = Reader.new(remote_io)
        yield reader
      end

      def read_from_disk(blob)
        blob.open do |file|
          reader = Reader.new(file)
          yield reader
        end
      end
  end
end
