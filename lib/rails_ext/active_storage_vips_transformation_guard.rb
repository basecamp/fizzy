# Active Storage's ImageMagick transformer enforces ActiveStorage.supported_image_processing_methods,
# but the vips transformer never reads that allowlist -- ImageMagick#validate_transformation is its
# only reader in the whole tree, and the base ImageProcessingTransformer#validate_transformation
# rejects only combine_options. So on the vips path we run there is no method-name enforcement at
# all, and CVE-2025-24293's removal of apply, loader, and saver from that list is inert.
#
# Every transformation name reaches libvips by dispatch. ImageProcessing's builder handles apply,
# loader, and saver itself and sends every other name through Chainable#method_missing into the
# operations list, where Processor#apply_operation hands it to Vips::Image#public_send. That leaves a
# signed variation key three distinct primitives:
#
#   loader: { loader: "x" }  ->  Vips::Image.public_send(:"xload", path, **options)
#   saver:  { saver:  "x" }  ->  image.public_send(:"xsave", path, **options)
#   <any other name>         ->  image.public_send(:<name>, argument)
#
# and apply launders all three: it re-enters the builder for each of its entries, and those entries
# are never revalidated because only top-level transformations reach validate_transformation.
#
# Vips.block_untrusted(true) in config/initializers/vips.rb gates untrusted *loaders* only. Savers
# are not flagged untrusted, and direct dispatch is not gated at all. With blocking on,
# dzsave: "<path>" writes an unbounded tile pyramid to an attacker-chosen path, and on our locked
# image_processing 1.14.0 instance_eval: "<ruby>" runs arbitrary code -- the side effect lands before
# the pipeline fails on the operation's nil return, so the eventual error is not a defense.
#
# So enforce the allowlist here the way ImageMagick does. It admits nothing dangerous on this path.
# Note the reachable surface is wider than Vips::Image's own methods: Vips::Image#method_missing
# resolves an unknown name against libvips operation nicknames, so allowlisted names reach those too.
# Counting all three routes, 30 of its 284 names resolve to anything at all -- 6 ImageProcessing
# macros, 21 libvips operations (affine, canny, colourspace, crop, flip, resize, sharpen, thumbnail
# and the like), and a few pure accessors (clone, format, log, median, size). None of them writes to
# disk or takes a filename, and every *save/*load nickname is absent. The other 254 resolve to
# nothing.
module ActiveStorageVipsTransformationGuard
  # CVE-2025-24293 removed loader and saver from the allowlist, but Attachments::VARIANTS signs
  # loader: { n: -1 } into variant URLs that never expire, so those names have to keep resolving.
  # Only a nested same-name selector is a dispatch primitive; ordinary option hashes are not.
  DISPATCHING_METHODS = %w[ loader saver ]

  private
    def validate_transformation(name, argument)
      method_name = name.to_s.tr("-", "_")

      if nested_selector?(method_name, argument)
        raise unsupported_transformation_method("#{method_name} with a nested #{method_name} selector")
      elsif !supported_vips_transformation_method?(method_name)
        raise unsupported_transformation_method(method_name)
      end

      super
    end

    def nested_selector?(method_name, argument)
      DISPATCHING_METHODS.include?(method_name) && argument.is_a?(Hash) &&
        argument.any? { |key, _| key.to_s == method_name }
    end

    def supported_vips_transformation_method?(method_name)
      DISPATCHING_METHODS.include?(method_name) ||
        ActiveStorage.supported_image_processing_methods.include?(method_name)
    end

    def unsupported_transformation_method(description)
      ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod.new \
        "The provided transformation method is not supported: #{description}."
    end
end

Rails.application.config.to_prepare do
  ActiveStorage::Transformers::Vips.prepend ActiveStorageVipsTransformationGuard
end
