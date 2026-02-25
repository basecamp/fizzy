class ZipFile::Reader::IO
  def initialize(entry, io)
    @entry = entry
    @io = io
    @extractor = @entry.extractor_from(@io)
  end

  def read(length = nil, buffer = nil)
    return nil if @extractor.eof?

    data = @extractor.extract(length)
    return nil if data.nil?

    if buffer
      buffer.replace(data)
      buffer
    else
      data
    end
  end

  def eof?
    @extractor.eof?
  end

  def rewind
    @extractor = @entry.extractor_from(@io)
    0
  end

  def size
    @entry.uncompressed_size
  end
end
