class ZipFile::Reader::IO
  STORED = 0

  def initialize(entry, io)
    @entry = entry
    @io = io
    rewind
  end

  def read(length = nil, buffer = nil)
    fill_buffer_for(length)
    return nil if eof?

    data = take(length)

    if buffer
      buffer.replace(data)
      buffer
    else
      data
    end
  end

  def eof?
    buffered.zero? && drained?
  end

  def rewind
    @extractor = @entry.extractor_from(@io)
    @buffer = "".b
    @consumed = 0
    @drained = false
    0
  end

  def size
    @entry.uncompressed_size
  end

  private
    def fill_buffer_for(length)
      until drained? || (length && buffered >= length)
        drop_consumed

        chunk = @extractor.extract(slice_size(length))

        if chunk.nil?
          @drained = true
        else
          @buffer << chunk
        end
      end
    end

    # An entry whose compressed data runs out before the deflate stream ends
    # leaves the extractor short of eof while it has nothing left to give, so
    # take its first nil as the end too rather than asking again forever.
    def drained?
      @drained || @extractor.eof?
    end

    # A deflated entry hands back whatever it inflates to, which is the archive
    # author's choice rather than the caller's: asking for five megabytes of a
    # crafted entry gets gigabytes back in one string. Read those in slices and
    # keep what the caller didn't ask for. A stored entry returns exactly the
    # bytes asked of it, so its reads pass straight through.
    def slice_size(length)
      if @entry.storage_mode == STORED
        length
      else
        [ ZipFile::Reader::EXTRACT_SLICE_SIZE, length ].compact.min
      end
    end

    def take(length)
      wanted = length ? [ length, buffered ].min : buffered

      @buffer.byteslice(@consumed, wanted).tap { @consumed += wanted }
    end

    def buffered
      @buffer.bytesize - @consumed
    end

    # Handing bytes out by moving a cursor rather than trimming the front keeps a
    # long run of small reads from recopying the rest of the buffer every time.
    def drop_consumed
      if @consumed > 0
        @buffer = @buffer.byteslice(@consumed..)
        @consumed = 0
      end
    end
end
