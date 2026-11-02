require "test_helper"

class RenderingVersionTest < ActiveSupport::TestCase
  # Fragments holding rich text are keyed by record, so a sanitizer fix alone leaves what was
  # rendered before it in the cache. The rendering version is what retires them, and the ETag
  # carries it so a browser's cached page goes too.
  test "fragments and page ETags have moved past what was rendered under loofah 2.25.2" do
    assert_equal "v3", ApplicationController::RENDERING_VERSION
    assert_includes evaluated(ApplicationController.fragment_cache_keys), "v3"
    assert_includes evaluated(ApplicationController.etaggers), "v3"
    assert_not_includes evaluated(ApplicationController.etaggers), "v2"
  end

  private
    def evaluated(blocks)
      blocks.filter_map do |block|
        ApplicationController.new.instance_exec(&block) rescue nil
      end
    end
end
