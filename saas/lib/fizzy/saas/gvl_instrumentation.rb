module Fizzy
  module Saas
    class GvlInstrumentation
      def initialize(app)
        @app = app
      end

      def call(env)
        GVLTools::LocalTimer.enable
        before = GVLTools::LocalTimer.monotonic_time
        result = @app.call(env)
        gvl_wait_ns = GVLTools::LocalTimer.monotonic_time - before
        Yabeda.gvl.request_wait.measure({}, gvl_wait_ns / 1_000_000_000.0)
        result
      ensure
        GVLTools::LocalTimer.disable
      end
    end
  end
end
