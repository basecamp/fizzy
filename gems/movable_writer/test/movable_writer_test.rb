require "test_helper"

class MovableWriterTest < ActiveSupport::TestCase
  test ".state returns the first record in the table" do
    MovableWriter::State.create! writer: "foobar-app-111"

    assert_equal MovableWriter::State.first, MovableWriter.state
  end

  test ".state creates a record if there isn't one" do
    assert_equal 0, MovableWriter::State.count

    MovableWriter.state

    assert_equal 1, MovableWriter::State.count
    assert_not_nil MovableWriter.state
    assert_nil MovableWriter.state.writer
  end

  test ".set_writer sets the writer in the state" do
    assert_nil MovableWriter.state.writer

    MovableWriter.set_writer "foobar-app-111"

    assert_equal "foobar-app-111", MovableWriter.state.writer
  end

  test ".writer delegates to .state" do
    assert_nil MovableWriter.writer

    MovableWriter.set_writer "foobar-app-111"

    assert_equal "foobar-app-111", MovableWriter.writer
  end

  test ".localhost returns the value of `KAMAL_HOST`" do
    with_localhost("fizzy-app-111") do
      assert_equal "fizzy-app-111", MovableWriter.localhost
    end
  end

  test ".localhost raises if `KAMAL_HOST` is not set" do
    with_localhost(nil) do
      assert_raises KeyError do
        MovableWriter.localhost
      end
    end
  end

  test ".writer? returns true if the local host is the writer" do
    # write the test
    with_localhost("fizzy-app-111") do
      MovableWriter.set_writer("fizzy-app-111")
      assert MovableWriter.writer?

      MovableWriter.set_writer("fizzy-app-222")
      assert_not MovableWriter.writer?
    end
  end

  test ".safe_request? return true for safe requests" do
    ["GET", "HEAD", "OPTIONS"].each do |method|
      request = ActionDispatch::Request.new("REQUEST_METHOD" => method, "PATH_INFO" => "/foo")
      assert MovableWriter.safe_request?(request)
    end

    ["PUT", "POST", "PATCH"].each do |method|
      request = ActionDispatch::Request.new("REQUEST_METHOD" => method, "PATH_INFO" => "/foo")
      assert_not MovableWriter.safe_request?(request)
    end
  end

  test "set_as_initial_writer? sets the local host as the writer if no writer is set" do
    assert_nil MovableWriter.writer

    with_localhost("fizzy-app-111") do
      assert MovableWriter.set_as_initial_writer?
      assert_equal "fizzy-app-111", MovableWriter.writer
    end

    with_localhost("fizzy-app-222") do
      assert_not MovableWriter.set_as_initial_writer?
      assert_equal "fizzy-app-111", MovableWriter.writer
    end
  end

  test "for safe requests, .acceptable_request? returns true" do
    MovableWriter.set_writer("fizzy-app-111")
    with_localhost("fizzy-app-222") do
      ["GET", "HEAD", "OPTIONS"].each do |method|
        request = ActionDispatch::Request.new("REQUEST_METHOD" => method, "PATH_INFO" => "/foo")
        assert MovableWriter.safe_request?(request)
      end
    end
  end

  test "for unsafe requests, .acceptable_request? returns true on the writer" do
    request = ActionDispatch::Request.new("REQUEST_METHOD" => "PUT", "PATH_INFO" => "/foo")
    with_localhost("fizzy-app-111") do
      MovableWriter.set_writer("fizzy-app-111")
      assert MovableWriter.acceptable_request?(request)

      MovableWriter.set_writer("fizzy-app-222")
      assert_not MovableWriter.acceptable_request?(request)
    end
  end

  test "for unsafe request when no writer is set, .acceptable_request? sets the local host as the writer" do
    request = ActionDispatch::Request.new("REQUEST_METHOD" => "PUT", "PATH_INFO" => "/foo")
    with_localhost("fizzy-app-111") do
      assert_nil MovableWriter.writer
      assert MovableWriter.acceptable_request?(request)
      assert_equal "fizzy-app-111", MovableWriter.writer
    end
  end

  test ".rack_error_response returns a 4xx rack error" do
    with_localhost("fizzy-app-111") do
      MovableWriter.set_writer("fizzy-app-222")
      response = MovableWriter.rack_error_response

      assert_equal 409, response[0]
      assert_equal "text/plain", response[1]["Content-Type"]
      assert_equal "fizzy-app-222", response[1]["X-Kamal-Writer"]
      assert_equal ["fizzy-app-111 is not the designated writer fizzy-app-222"], response[2]
    end
  end

  test ".inject_header adds a custom header to the response" do
    with_localhost("fizzy-app-111") do
      MovableWriter.set_writer("fizzy-app-222")
      response = MovableWriter.inject_header([200, {}, ["OK"]])

      assert_equal "fizzy-app-222", response[1]["X-Kamal-Writer"]
    end
  end
end
