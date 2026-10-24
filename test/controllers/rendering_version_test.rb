require "test_helper"

class RenderingVersionTest < ActiveSupport::TestCase
  # Fragments holding rich text are keyed by record, so a sanitizer fix alone leaves what was
  # rendered before it in the cache. The rendering version is what retires them, and the ETag
  # carries it so a browser's cached page goes too.
  test "fragments and page ETags have moved past what was rendered under crass 1.0.7" do
    assert_equal "v2", ApplicationController::RENDERING_VERSION
    assert_includes evaluated(ApplicationController.fragment_cache_keys), "v2"
    assert_includes evaluated(ApplicationController.etaggers), "v2"
    assert_not_includes evaluated(ApplicationController.etaggers), "v1"
  end

  private
    def evaluated(blocks)
      blocks.filter_map do |block|
        ApplicationController.new.instance_exec(&block) rescue nil
      end
    end
end
