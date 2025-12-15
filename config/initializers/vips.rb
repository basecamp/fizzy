# Disable Openslide to prevent sqlite segfault in forked parallel workers
# Requires libvips 8.13+
Vips.block "VipsForeignLoadOpenslide", true if Vips.respond_to?(:block)

# Limit libvips to 4 threads for each thread pool. Default is #CPUs.
Vips.concurrency_set(4) if Vips.respond_to?(:concurrency_set)

# Limit libvips caches to reduce memory pressure.
#
# Do not disable entirely since libvips relies on some caching internally.
# (When we disabled caches, we hit a ton of JPEG out of order read errors.)
Vips.cache_set_max(10)               if Vips.respond_to?(:cache_set_max) # Default 100
Vips.cache_set_max_mem(10.megabytes) if Vips.respond_to?(:cache_set_max_mem) # Default 100MB
Vips.cache_set_max_files(10)         if Vips.respond_to?(:cache_set_max_files) # Default 100



