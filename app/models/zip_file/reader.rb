class ZipFile::Reader
  # Entries read into memory hold one database record each, and the largest
  # column any of them can fill is a rich text body; every other text column the
  # export writes tops out at 64KB. Reading them with no ceiling let a
  # two-megabyte upload inflate to gigabytes inside a jobs worker.
  MAX_BUFFERED_ENTRY_SIZE = 2.megabytes

  # The extractor is fed compressed bytes, so how much it hands back in one call
  # is the archive author's choice: a maximally compressible slice expands about
  # a thousandfold. Slicing here keeps every real record a single read of the
  # archive, which matters on S3 where each read is its own range request, while
  # capping what one call can return at tens of megabytes.
  EXTRACT_SLICE_SIZE = 64.kilobytes

  # Deflating each entry on its own is what makes an archive's total expansion a
  # usable signal: a real export barely shrinks, since records are small and per
  # entry overhead eats the savings, while a crafted one expands a thousandfold.
  # Budgeting everything read out of an archive against what was actually
  # uploaded bounds the streaming path too, where an entry's own declared size is
  # the archive author's word. The floor keeps a small archive holding one large
  # rich text body importable.
  MAX_TOTAL_EXPANSION = 100
  MIN_EXPANSION_BUDGET = 64.megabytes

  def initialize(io)
    @io = io
    @reader = ZipKit::FileReader.read_zip_structure(io: io)
    @expanded = 0
    @budget = [ io.size * MAX_TOTAL_EXPANSION, MIN_EXPANSION_BUDGET ].max
  rescue ZipKit::FileReader::ReadError, ZipKit::FileReader::MissingEOCD, ZipKit::FileReader::UnsupportedFeature => e
    raise ZipFile::InvalidFileError, e.message
  end

  def read(file_path, max_bytes: MAX_BUFFERED_ENTRY_SIZE)
    entry = @reader.find { |e| e.filename == file_path }
    raise ArgumentError, "File not found in zip: #{file_path}" unless entry
    raise ArgumentError, "Cannot read directory entry: #{file_path}" if entry.filename.end_with?("/")

    if block_given?
      yield ZipFile::Reader::IO.new(entry, @io, self)
    else
      extract_within(entry, max_bytes)
    end
  end

  def glob(pattern)
    @reader.map(&:filename).select { |name| File.fnmatch(pattern, name) }.sort
  end

  def exists?(file_path)
    @reader.any? { |e| e.filename == file_path }
  end

  # Called for every byte handed out, buffered or streamed.
  def count_expanded(bytes)
    @expanded += bytes

    if @expanded > @budget
      raise ZipFile::ArchiveTooLargeError,
        "archive has produced #{@expanded} bytes, over the #{@budget} byte limit for its size"
    end
  end

  private
    def extract_within(entry, max_bytes)
      ensure_within entry, entry.uncompressed_size, max_bytes

      extractor = entry.extractor_from(@io)
      content = "".b

      until extractor.eof?
        chunk = extractor.extract(EXTRACT_SLICE_SIZE)
        break if chunk.nil?

        count_expanded chunk.bytesize
        content << chunk
        ensure_within entry, content.bytesize, max_bytes
      end

      content
    end

    # The size an entry declares is the archive author's word, so the bytes that
    # come out of the extractor are counted as well.
    def ensure_within(entry, bytes, max_bytes)
      if bytes > max_bytes
        raise ZipFile::EntryTooLargeError,
          "#{entry.filename} expands to at least #{bytes} bytes, over the #{max_bytes} byte limit"
      end
    end
end
