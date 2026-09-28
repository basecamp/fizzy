require "test_helper"

# OpenMP reads the host's core count, not the container's CPU quota, so an unbounded cell asks for one
# thread per core, and each 8MB stack is charged to the worker's RLIMIT_DATA. Past about a hundred
# threads pthread_create returns EAGAIN and libgomp exits the process outright. Held here rather than in
# a cell test because no host we run tests on has enough cores to provoke it: beta has 4 and production
# has far more, which is exactly how this reached production in bc3's hotcell.
class HotcellImageTest < ActiveSupport::TestCase
  DOCKERFILE = Rails.root.join("saas/hotcell/Dockerfile")

  test "the cell bounds every OpenMP thread pool" do
    dockerfile = DOCKERFILE.read

    assert_match(/^(?:ENV )?\s*OMP_NUM_THREADS=2\b/, dockerfile)
    assert_match(/^(?:ENV )?\s*OMP_THREAD_LIMIT=8\b/, dockerfile)
  end

  # Held here because the accessory's `no-new-privileges` covers this too, so dropping the strip breaks
  # nothing a running cell can show you.
  test "the cell carries no setuid or setgid binary" do
    assert_match "find / -xdev -type f -perm /06000 -exec chmod a-s {} +", DOCKERFILE.read
  end
end
