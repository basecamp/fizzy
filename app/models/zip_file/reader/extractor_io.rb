class ZipFile::Reader::ExtractorIO
  def initialize(extractor)
    @extractor = extractor
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
end
