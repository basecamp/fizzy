require "test_helper"

class ActiveStorageVipsTransformationGuardTest < ActiveSupport::TestCase
  UnsupportedMethod = ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod

  setup do
    @blob = ActiveStorage::Blob.create_and_upload! \
      io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
  end

  # The guard rejects the transformation methods that let a signed variation key choose an
  # arbitrary libvips operation. On the vips path ImageProcessing dispatches the loader/saver by
  # name -- Vips::Image.public_send(:"#{loader}load") / image.public_send(:"#{saver}save") -- when
  # the options carry a nested loader:/saver: selector, and apply re-enters the builder to reach
  # the same selectors.

  test "apply is rejected outright as builder machinery" do
    assert_raises(UnsupportedMethod) { @blob.variant(apply: { resize_to_limit: [ 100, 100 ] }).processed }
    assert_raises(UnsupportedMethod) { @blob.variant(apply: { saver: { saver: "dz" } }).processed }
  end

  test "a nested loader selector is rejected" do
    assert_raises(UnsupportedMethod) { @blob.variant(loader: { loader: "magick" }).processed }
  end

  test "a nested saver selector is rejected" do
    # saver dispatch is NOT gated by Vips.block_untrusted(true); this guard is the only thing that
    # stops saver: { saver: "dz" } (a tile-pyramid resource amplifier) from reaching libvips.
    assert_raises(UnsupportedMethod) { @blob.variant(saver: { saver: "dz" }).processed }
  end

  # Non-vacuity: the guard must not reject legitimate transformations. Attachments::VARIANTS depends
  # on loader: { n: -1 } to keep animated GIF frames, and those keys are signed into immortal URLs.

  test "loader option hashes without a nested selector still process" do
    assert_nothing_raised do
      @blob.variant(loader: { n: -1 }, resize_to_limit: [ 100, 100 ]).processed
    end
  end

  test "the real Attachments::VARIANTS still process" do
    Attachments::VARIANTS.each_value do |options|
      assert_nothing_raised { @blob.variant(**options).processed }
    end
  end

  test "an ordinary resize still processes" do
    assert_nothing_raised { @blob.variant(resize_to_limit: [ 50, 50 ]).processed }
  end
end
