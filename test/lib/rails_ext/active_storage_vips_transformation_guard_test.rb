require "test_helper"
require "tmpdir"

class ActiveStorageVipsTransformationGuardTest < ActiveSupport::TestCase
  UnsupportedMethod = ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod

  setup do
    @blob = ActiveStorage::Blob.create_and_upload! \
      io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
  end

  # The guard enforces ActiveStorage.supported_image_processing_methods on the vips path, which
  # nothing in Rails does. Without it a signed variation key picks any libvips operation: the builder
  # handles apply/loader/saver itself, and hands every other name to Vips::Image#public_send.

  test "apply is rejected as builder machinery that launders its unvalidated entries" do
    assert_raises(UnsupportedMethod) { @blob.variant(apply: { resize_to_limit: [ 100, 100 ] }).processed }
    assert_raises(UnsupportedMethod) { @blob.variant(apply: { saver: { saver: "dz" } }).processed }
  end

  test "a nested loader selector is rejected" do
    assert_raises(UnsupportedMethod) { @blob.variant(loader: { loader: "magick" }).processed }
  end

  test "a nested saver selector is rejected" do
    # Saver dispatch is NOT gated by Vips.block_untrusted(true); this guard is the only thing that
    # stops saver: { saver: "dz" } (a tile-pyramid resource amplifier) from reaching libvips.
    assert_raises(UnsupportedMethod) { @blob.variant(saver: { saver: "dz" }).processed }
  end

  test "an unknown method name is rejected rather than dispatched to the image" do
    assert_raises(UnsupportedMethod) { @blob.variant(bogusnotreal: true).processed }
  end

  test "a libvips operation nickname is rejected even though libvips knows it" do
    # Vips::Image#method_missing resolves unknown names against libvips operation nicknames, so the
    # reachable surface is wider than Vips::Image's own methods. These are real operations.
    assert_raises(UnsupportedMethod) { @blob.variant(gaussblur: 5).processed }
    assert_raises(UnsupportedMethod) { @blob.variant(invert: true).processed }
  end

  test "combine_options is still rejected by the base transformer" do
    # Pins the super chain: the guard raises for its own cases but must keep delegating, or the
    # base ImageProcessingTransformer's only check silently disappears.
    assert_raises(ArgumentError) { @blob.variant(combine_options: { resize: "100x100" }).processed }
  end

  # A direct operation name needs no nested selector: Chainable#method_missing turns it into an
  # operation and Processor#apply_operation calls Vips::Image#public_send with it. The argument is
  # the *destination path*, so this writes where the transformation says, not to Active Storage's
  # tempfile. Asserting the exception alone would be vacuous -- before the guard these raised too,
  # on the operation's nil return, long after the write had landed. Assert the side effect is absent.

  test "direct saver operation names are rejected before libvips writes anything" do
    Dir.mktmpdir do |dir|
      { dzsave: "pyramid", csvsave: "leak.csv", matrixsave: "leak.mat" }.each do |name, basename|
        assert_raises(UnsupportedMethod, "#{name} must not reach libvips") do
          @blob.variant(name => File.join(dir, basename)).processed
        end
      end

      assert_empty Dir.children(dir), "the guard must reject before any saver runs"
    end
  end

  test "write_to_file is rejected before libvips writes anything" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "arbitrary.png")
      assert_raises(UnsupportedMethod) { @blob.variant(write_to_file: path).processed }
      assert_not File.exist?(path), "write_to_file must not reach the image"
    end
  end

  test "Ruby object methods are rejected before they execute" do
    # image_processing 1.14.0 does not restrict dispatch to libvips operations, so an inherited
    # Object method is reachable on the accumulator. 2.0 hardens apply but not this path.
    Dir.mktmpdir do |dir|
      marker = File.join(dir, "executed.txt")
      assert_raises(UnsupportedMethod) do
        @blob.variant(instance_eval: "File.write(#{marker.inspect}, 'x')").processed
      end
      assert_not File.exist?(marker), "instance_eval must never reach the image"
    end
  end

  # Non-vacuity: the guard must not reject legitimate transformations. Attachments::VARIANTS depends
  # on loader: { n: -1 } to keep animated GIF frames, and those keys are signed into variant URLs
  # that never expire, so an allowlist that drops loader/saver would break every existing URL.

  test "loader option hashes without a nested selector still process" do
    assert_nothing_raised do
      @blob.variant(loader: { n: -1 }, resize_to_limit: [ 100, 100 ]).processed
    end
  end

  test "saver option hashes without a nested selector still process" do
    assert_nothing_raised { @blob.variant(saver: { quality: 80 }).processed }
  end

  test "the real Attachments::VARIANTS still process" do
    Attachments::VARIANTS.each_value do |options|
      assert_nothing_raised { @blob.variant(**options).processed }
    end
  end

  test "the real User::Avatar variant still processes" do
    assert_nothing_raised { @blob.variant(resize_to_fill: [ 256, 256 ]).processed }
  end

  test "an ordinary resize still processes" do
    assert_nothing_raised { @blob.variant(resize_to_limit: [ 50, 50 ]).processed }
  end
end
