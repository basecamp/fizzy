raise LoadError, "Please install libvips" unless defined?(Vips::LIBRARY_VERSION)

# Disable Openslide to prevent sqlite segfault in forked parallel workers
# Requires libvips 8.13+
Vips.block "VipsForeignLoadOpenslide", true if Vips.respond_to?(:block)

# Limit libvips to 4 threads for each thread pool. Default is #CPUs.
Vips.concurrency_set 4

# Limit libvips caches to reduce memory pressure.
#
# Do not disable entirely since libvips relies on some caching internally.
# (When we disabled caches, we hit a ton of JPEG out of order read errors.)
Vips.cache_set_max 10               # Default 100
Vips.cache_set_max_mem 10.megabytes # Default 100MB
Vips.cache_set_max_files 10         # Default 100
