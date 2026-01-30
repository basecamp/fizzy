class ZipFile::Reader
  def initialize(io)
    @io = io
    @reader = ZipKit::FileReader.read_zip_structure(io: io)
  end

  def read(file_path)
    entry = @reader.find { |e| e.filename == file_path }
    raise ArgumentError, "File not found in zip: #{file_path}" unless entry
    raise ArgumentError, "Cannot read directory entry: #{file_path}" if entry.filename.end_with?("/")

    extractor = entry.extractor_from(@io)

    if block_given?
      yield ZipFile::Reader::ExtractorIO.new(extractor)
    else
      extractor.extract
    end
  end

  def glob(pattern)
    @reader.map(&:filename).select { |name| File.fnmatch(pattern, name) }.sort
  end

  def exists?(file_path)
    @reader.any? { |e| e.filename == file_path }
  end
end
