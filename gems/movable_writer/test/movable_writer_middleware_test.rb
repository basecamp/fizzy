require "test_helper"

class TestMiddleware < ActiveSupport::TestCase
  setup do
    MovableWriter.set_writer "fizzy-test-111"
  end

  test "read to a reader succeeds" do
    write_checker = MovableWriter::Middleware::WriteCheck.new(fake_app)

    response = with_localhost("fizzy-test-222") do
      write_checker.call(fake_env("GET"))
    end

    assert_equal 200, response[0]
    assert_equal "fizzy-test-111", response[1]["X-Kamal-Writer"]
    assert_equal "OK", response[2].first
  end

  test "write to a reader fails" do
    write_checker = MovableWriter::Middleware::WriteCheck.new(fake_app)

    response = with_localhost("fizzy-test-222") do
      write_checker.call(fake_env("PUT"))
    end

    assert_equal 409, response[0]
    assert_equal "fizzy-test-111", response[1]["X-Kamal-Writer"]
    assert_match(/not the designated writer/, response[2].first)
  end

  test "read to the writer succeeds" do
    write_checker = MovableWriter::Middleware::WriteCheck.new(fake_app)

    response = with_localhost("fizzy-test-111") do
      write_checker.call(fake_env("GET"))
    end

    assert_equal 200, response[0]
    assert_equal "fizzy-test-111", response[1]["X-Kamal-Writer"]
    assert_equal "OK", response[2].first
  end

  test "write to the writer succeeds" do
    write_checker = MovableWriter::Middleware::WriteCheck.new(fake_app)

    response = with_localhost("fizzy-test-111") do
      write_checker.call(fake_env("PUT"))
    end

    assert_equal 200, response[0]
    assert_equal "fizzy-test-111", response[1]["X-Kamal-Writer"]
    assert_equal "OK", response[2].first
  end

  private
    def fake_app
      @fake_app = Class.new do
        attr_reader :env

        def call(env)
          @env = env

          [ 200, {}, [ "OK" ] ]
        end
      end.new
    end

    def fake_env(method)
      { "REQUEST_METHOD" => method, "PATH_INFO" => "/test" }
    end
end
