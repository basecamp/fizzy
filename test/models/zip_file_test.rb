require "test_helper"

class ZipFileTest < ActiveSupport::TestCase
  test "writer adds files with content" do
    tempfile = Tempfile.new([ "test", ".zip" ])
    tempfile.binmode

    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("hello.txt", "Hello, World!")
    writer.close

    assert writer.exists?("hello.txt")
    assert_not writer.exists?("missing.txt")
  end

  test "writer adds files with block" do
    tempfile = Tempfile.new([ "test", ".zip" ])
    tempfile.binmode

    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("hello.txt") { |sink| sink.write("Hello, World!") }
    writer.close

    assert writer.exists?("hello.txt")
  end

  test "writer globs entries" do
    tempfile = Tempfile.new([ "test", ".zip" ])
    tempfile.binmode

    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("docs/readme.txt", "Readme")
    writer.add_file("docs/guide.txt", "Guide")
    writer.add_file("images/logo.png", "PNG data")
    writer.close

    assert_equal [ "docs/guide.txt", "docs/readme.txt" ], writer.glob("docs/*.txt")
    assert_equal [ "images/logo.png" ], writer.glob("**/*.png")
  end

  test "reader reads file content" do
    tempfile = create_test_zip("hello.txt" => "Hello, World!")

    reader = ZipFile::Reader.new(tempfile)
    content = reader.read("hello.txt")

    assert_equal "Hello, World!", content
  end

  test "reader reads file with block" do
    tempfile = create_test_zip("hello.txt" => "Hello, World!")

    reader = ZipFile::Reader.new(tempfile)
    content = nil
    reader.read("hello.txt") { |io| content = io.read }

    assert_equal "Hello, World!", content
  end

  test "reader raises for missing file" do
    tempfile = create_test_zip("hello.txt" => "Hello")

    reader = ZipFile::Reader.new(tempfile)

    assert_raises(ArgumentError) { reader.read("missing.txt") }
  end

  test "reader checks file existence" do
    tempfile = create_test_zip("hello.txt" => "Hello")

    reader = ZipFile::Reader.new(tempfile)

    assert reader.exists?("hello.txt")
    assert_not reader.exists?("missing.txt")
  end

  test "reader globs entries" do
    tempfile = create_test_zip(
      "docs/readme.txt" => "Readme",
      "docs/guide.txt" => "Guide",
      "images/logo.png" => "PNG"
    )

    reader = ZipFile::Reader.new(tempfile)

    assert_equal [ "docs/guide.txt", "docs/readme.txt" ], reader.glob("docs/*.txt")
  end

  test "reader io provides size" do
    tempfile = create_test_zip("hello.txt" => "Hello, World!")

    reader = ZipFile::Reader.new(tempfile)
    reader.read("hello.txt") do |io|
      assert_equal 13, io.size
    end
  end

  test "reader io supports rewind" do
    tempfile = create_test_zip("hello.txt" => "Hello, World!")

    reader = ZipFile::Reader.new(tempfile)
    reader.read("hello.txt") do |io|
      first_read = io.read
      io.rewind
      second_read = io.read

      assert_equal first_read, second_read
    end
  end

  test "reader io tracks eof" do
    tempfile = create_test_zip("hello.txt" => "Hello")

    reader = ZipFile::Reader.new(tempfile)
    reader.read("hello.txt") do |io|
      assert_not io.eof?
      io.read
      assert io.eof?
    end
  end

  test "reader reads an entry at the size limit" do
    content = "a" * ZipFile::Reader::MAX_BUFFERED_ENTRY_SIZE
    tempfile = create_test_zip("data/tags/big.json" => content)

    reader = ZipFile::Reader.new(tempfile)

    assert_equal content.bytesize, reader.read("data/tags/big.json").bytesize
  end

  test "reader raises EntryTooLargeError for an entry over the size limit" do
    content = "a" * (ZipFile::Reader::MAX_BUFFERED_ENTRY_SIZE + 1)
    tempfile = create_test_zip("data/tags/bomb.json" => content)

    reader = ZipFile::Reader.new(tempfile)

    assert_raises(ZipFile::EntryTooLargeError) { reader.read("data/tags/bomb.json") }
  end

  test "reader raises EntryTooLargeError when the zip understates an entry's size" do
    content = "a" * (4 * ZipFile::Reader::MAX_BUFFERED_ENTRY_SIZE)
    tempfile = understate_declared_size(create_test_zip("data/tags/bomb.json" => content), "data/tags/bomb.json", 1024)

    reader = ZipFile::Reader.new(tempfile)

    assert_equal 1024, reader.instance_variable_get(:@reader).find { |e| e.filename == "data/tags/bomb.json" }.uncompressed_size
    assert_raises(ZipFile::EntryTooLargeError) { reader.read("data/tags/bomb.json") }
  end

  test "reader streams an entry over the size limit when given a block" do
    content = "a" * (2 * ZipFile::Reader::MAX_BUFFERED_ENTRY_SIZE)
    tempfile = create_test_zip("storage/blob_key" => content)

    reader = ZipFile::Reader.new(tempfile)
    streamed = 0
    reader.read("storage/blob_key") do |io|
      streamed += io.read.bytesize until io.eof?
    end

    assert_equal content.bytesize, streamed
  end

  test "reader io returns no more than the length asked for from a deflated entry" do
    content = "a" * 2.megabytes
    tempfile = create_test_zip("storage/blob_key" => content)

    reader = ZipFile::Reader.new(tempfile)
    reader.read("storage/blob_key") do |io|
      assert_equal 1024, io.read(1024).bytesize
    end
  end

  test "reader io streams a deflated entry intact in small reads" do
    content = ("fizzy" * 200_000).b
    tempfile = create_test_zip("storage/blob_key" => content)

    reader = ZipFile::Reader.new(tempfile)
    streamed = "".b
    reader.read("storage/blob_key") do |io|
      while chunk = io.read(7919)
        streamed << chunk
      end
    end

    assert_equal content, streamed
  end

  test "reader io stops at a truncated deflate stream" do
    tempfile = understate_declared_size(create_test_zip("storage/blob_key" => "a" * 64.kilobytes), "storage/blob_key", 16, offset: 20)

    reader = ZipFile::Reader.new(tempfile)
    reads = 0
    reader.read("storage/blob_key") do |io|
      reads += 1 while io.read(1024)
    end

    assert_operator reads, :<, 100
  end

  test "reader raises ArchiveTooLargeError when a streamed entry expands past what the archive can account for" do
    tempfile = Tempfile.new([ "bomb", ".zip" ])
    tempfile.binmode
    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("storage/blob_key") do |sink|
      chunk = "a" * 1.megabyte
      80.times { sink.write(chunk) }
    end
    writer.close
    tempfile.rewind

    reader = ZipFile::Reader.new(tempfile)
    streamed = 0

    error = assert_raises(ZipFile::ArchiveTooLargeError) do
      reader.read("storage/blob_key") do |io|
        streamed += io.read(64.kilobytes).bytesize until io.eof?
      end
    end

    assert_operator streamed, :<, 80.megabytes
    assert_match(/over the \d+ byte limit/, error.message)
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  test "reader raises InvalidFileError for non-zip file" do
    tempfile = Tempfile.new([ "not_a_zip", ".zip" ])
    tempfile.write("this is not a zip file at all")
    tempfile.rewind

    assert_raises(ZipFile::InvalidFileError) { ZipFile::Reader.new(tempfile) }
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  private
    # Rewrites a size the central directory declares for one entry, the way a
    # crafted archive would: offset 24 is the uncompressed size, 20 the
    # compressed one.
    def understate_declared_size(tempfile, path, size, offset: 24)
      bytes = File.binread(tempfile.path)
      cdir = 0

      while cdir = bytes.index("PK\x01\x02".b, cdir)
        name_length = bytes[cdir + 28, 2].unpack1("v")

        if bytes[cdir + 46, name_length] == path.b
          bytes[cdir + offset, 4] = [ size ].pack("V")
          break
        end

        cdir += 4
      end

      Tempfile.new([ "understated", ".zip" ]).tap do |patched|
        patched.binmode
        patched.write(bytes)
        patched.rewind
      end
    end

    def create_test_zip(files)
      tempfile = Tempfile.new([ "test", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      files.each { |path, content| writer.add_file(path, content) }
      writer.close

      tempfile.rewind
      tempfile
    end
end
