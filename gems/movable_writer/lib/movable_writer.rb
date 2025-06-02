# frozen_string_literal: true

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

module MovableWriter
  class << self
    #
    #  Returns the current state, initializing the record to columns with `nil` values if it does
    #  not yet exist.
    #
    def state
      State.first || State.create!
    end

    #
    #  Returns the designated writer.
    #
    delegate :writer, to: :state

    #
    #  Designates `hostname` as the writer.
    #
    def set_writer(hostname)
      state.update!(writer: hostname)
    end

    #
    #  Returns true if `request` is either a "safe" HTTP request, or if the local host is the
    #  designated writer.
    #
    #  If this is not a safe request and no writer is currently set, then the local host becomes the
    #  designated writer.
    #
    def acceptable_request?(request)
      safe_request?(request) || MovableWriter.writer? || MovableWriter.set_as_initial_writer?
    end

    #
    #  Returns true if the local host is the designated writer.
    #
    def writer?
      localhost == writer
    end

    #
    #  Returns the name of the local host. If the environment variable `KAMAL_HOST` is not set, it
    #  raises an error.
    #
    def localhost
      ENV.fetch("KAMAL_HOST")
    end

    #
    #  If no writer is currently set, the local host is set as the writer and `true` is returned.
    #  If a writer is currently set, this method does nothing and `nil` is returned.
    #
    def set_as_initial_writer?
      if writer.nil?
        set_writer(localhost)
        true
      end
    end

    #
    #  Returns a Rack response indicating that the local host is not the designated writer. This is
    #  used by the Middleware::WriteCheck middleware to indicate that the request may have been
    #  misrouted.
    #
    def rack_error_response
      inject_header [ 409, { "Content-Type" => "text/plain" }, [ "#{MovableWriter.localhost} is not the designated writer #{MovableWriter.writer}" ] ]
    end

    #
    #  Injects a custom header into the Rack response to identify the designated writer to the
    #  proxy or routing tier.
    #
    def inject_header(response)
      headers = response[1]
      headers["X-Kamal-Writer"] = MovableWriter.writer
      response
    end

    #
    #  Returns true if the request is a "safe" HTTP request (GET, HEAD, OPTIONS).
    #  See https://developer.mozilla.org/en-US/docs/Glossary/Safe/HTTP
    #
    def safe_request?(request)
      request.get? || request.head? || request.options?
    end
  end
end

loader.eager_load

ActiveSupport.run_load_hooks :movable_writer, MovableWriter
