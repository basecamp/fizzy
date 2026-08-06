# Active Storage's ImageMagick transformer enforces ActiveStorage.supported_image_processing_methods,
# but the vips transformer never reads that allowlist. So CVE-2025-24293's removal of apply, loader,
# and saver from the allowlist is inert on the vips path we run, and a signed variation key can still
# carry them.
#
# They are not inert on vips. ImageProcessing dispatches the loader/saver by name --
# Vips::Image.public_send(:"#{loader}load", ...) and image.public_send(:"#{saver}save", ...) --
# whenever the options carry a nested loader:/saver: selector, and apply re-enters the builder for
# each of its entries, reaching those same selectors regardless of any per-method check.
#
# config/initializers/vips.rb calls Vips.block_untrusted(true), which gates untrusted *loaders*, so
# loader: { loader: "openslide" } is already blocked. But savers are not flagged untrusted, so
# saver: { saver: "dz" } (dzsave, which expands one request into an unbounded tile pyramid on disk)
# and csv/matrix (text served back as an image) still reach libvips. Only method-level enforcement
# removes that primitive.
#
# Reject apply outright, and reject a nested loader:/saver: selector, while still accepting ordinary
# option hashes -- notably loader: { n: -1 }, which Attachments::VARIANTS relies on to keep animated
# GIF frames, and which is signed into immortal variant URLs.
module ActiveStorageVipsTransformationGuard
  private
    def validate_transformation(name, argument)
      case name.to_s
      when "apply"
        raise unsupported_transformation_method("apply")
      when "loader", "saver"
        if argument.is_a?(Hash) && argument.any? { |key, _| key.to_s == name.to_s }
          raise unsupported_transformation_method("#{name} with a nested #{name} selector")
        end
      end

      super
    end

    def unsupported_transformation_method(description)
      ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod.new \
        "The provided transformation method is not supported: #{description}."
    end
end

Rails.application.config.to_prepare do
  ActiveStorage::Transformers::Vips.prepend ActiveStorageVipsTransformationGuard
end
