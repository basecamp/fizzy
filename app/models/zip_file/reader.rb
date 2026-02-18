class ZipFile::Reader
  def initialize(io)
    @io = io
    @reader = ZipKit::FileReader.read_zip_structure(io: io)
  rescue ZipKit::FileReader::ReadError, ZipKit::FileReader::MissingEOCD, ZipKit::FileReader::UnsupportedFeature => e
    raise ZipFile::InvalidFileError, e.message
  end

  def read(file_path)
    entry = @reader.find { |e| e.filename == file_path }
    raise ArgumentError, "File not found in zip: #{file_path}" unless entry
    raise ArgumentError, "Cannot read directory entry: #{file_path}" if entry.filename.end_with?("/")

    if block_given?
      yield ZipFile::Reader::IO.new(entry, @io)
    else
      entry.extractor_from(@io).extract
    end
  end

  def glob(pattern)
    @reader.map(&:filename).select { |name| File.fnmatch(pattern, name) }.sort
  end

  def exists?(file_path)
    @reader.any? { |e| e.filename == file_path }
  end
end
