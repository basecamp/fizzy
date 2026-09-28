# These formats are never varied, whether conversions run in-app or in a cell.
Rails.application.config.active_storage.variable_content_types -=
    %w[ image/bmp image/tiff image/vnd.microsoft.icon image/vnd.adobe.photoshop ]

# When a hotcell cell carries the conversions, no image is ever parsed in this process and the cell
# configures its own libvips.
unless defined?(Fizzy::Saas::Cell) && Fizzy::Saas::Cell.enabled?
  raise LoadError, "Please install libvips" unless defined?(Vips::LIBRARY_VERSION)

  # Disable unfuzzed libvips operations.
  #
  # To block loaders we need to call `Vips.block` after Rails and image_processing set their
  # defaults. Force the order of operations by autoloading the file now.
  ActiveStorage::Transformers::Vips
  Vips.block_untrusted(true)
  Vips.block("VipsForeignLoadOpenslide", true) # prevent sqlite segfault in forked parallel workers
  Vips.block("VipsForeignLoadTiff", true) # unused; the variable_content_types list above only gates variants, not parsing

  # Limit libvips to 4 threads for each thread pool. Default is #CPUs.
  Vips.concurrency_set 4

  # Limit libvips caches to reduce memory pressure.
  #
  # Do not disable entirely since libvips relies on some caching internally.
  # (When we disabled caches, we hit a ton of JPEG out of order read errors.)
  Vips.cache_set_max 10               # Default 100
  Vips.cache_set_max_mem 10.megabytes # Default 100MB
  Vips.cache_set_max_files 10         # Default 100
end
