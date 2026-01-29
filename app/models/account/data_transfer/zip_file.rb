class Account::DataTransfer::ZipFile
  class << self
    def create
      raise ArgumentError, "No block given" unless block_given?

      Tempfile.new([ "export", ".zip" ]).tap do |tempfile|
        Zip::File.open(tempfile.path, create: true) do |zip|
          yield new(zip)
        end
      end
    end

    def open(path)
      raise ArgumentError, "No block given" unless block_given?

      Zip::File.open(path.to_s) do |zip|
        yield new(zip)
      end
    end
  end

  def initialize(zip)
    @zip = zip
  end

  def add_file(path, content = nil, compress: true, &block)
    if block_given?
      compression = compress ? nil : Zip::Entry::STORED
      zip.get_output_stream(path, compression_method: compression, &block)
    else
      zip.get_output_stream(path) { |f| f.write(content) }
    end
  end

  def glob(pattern)
    zip.glob(pattern).map(&:name).sort
  end

  def read(file_path, &block)
    entry = zip.find_entry(file_path)
    raise ArgumentError, "File not found in zip: #{file_path}" unless entry
    raise ArgumentError, "Cannot read directory entry: #{file_path}" if entry.directory?

    if block_given?
      yield entry.get_input_stream
    else
      entry.get_input_stream.read
    end
  end

  def exists?(file_path)
    zip.find_entry(file_path).present?
  end

  private
    attr_reader :zip
end
