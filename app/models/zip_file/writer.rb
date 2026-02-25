class ZipFile::Writer
  attr_reader :byte_size

  def initialize(io = nil)
    @entries = []
    @byte_size = 0
    @output_io = io
    @streamer = nil
    @digest = Digest::MD5.new
  end

  def stream_to(io)
    @output_io = io
  end

  def write(data)
    @output_io.write(data)
    @byte_size += data.bytesize
    @digest.update(data)
    data.bytesize
  end

  def add_file(path, content = nil, compress: true)
    @entries << path
    write_method = compress ? :write_deflated_file : :write_stored_file

    if block_given?
      streamer.public_send(write_method, path) { |sink| yield sink }
    else
      streamer.public_send(write_method, path) { |sink| sink.write(content) }
    end
  end

  def glob(pattern)
    @entries.select { |e| File.fnmatch(pattern, e) }.sort
  end

  def exists?(path)
    @entries.include?(path)
  end

  def close
    streamer.close
  end

  def checksum
    Base64.strict_encode64(@digest.digest)
  end

  private
    def streamer
      @streamer ||= ZipKit::Streamer.new(@output_io)
    end
end
