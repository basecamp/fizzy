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

  private
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
