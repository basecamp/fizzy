# frozen_string_literal: true

module MovableWriter
  module Middleware
    class WriteCheck
      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        if MovableWriter.acceptable_request?(request)
          response = @app.call(env)
          MovableWriter.inject_header(response)
        else
          MovableWriter.rack_error_response
        end
      end
    end
  end
end
