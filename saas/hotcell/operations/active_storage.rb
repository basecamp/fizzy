# frozen_string_literal: true

# Required one file at a time rather than through the gem's entry point, which also loads the ImageMagick
# and Poppler operations — tools this image does not carry.

require "active_storage/hot_cell/server/transformers/image/vips"
require "active_storage/hot_cell/server/analyzers/image/vips"
require "active_storage/hot_cell/server/analyzers/media/ffprobe"
require "active_storage/hot_cell/server/previewers/pdf/mutool"
require "active_storage/hot_cell/server/previewers/video/ffmpeg"

# The gem's 48MB is too small for a 48MP phone photo. 256MB covers every current phone.
ActiveStorage::HotCell::Server::Transformers::Image::Vips.limits file_size: 256 * 1024**2

# Mirrors config/initializers/vips.rb: openslide segfaults sqlite in forked workers, and tiff is a format
# Fizzy never reads.
Vips.block "VipsForeignLoadOpenslide", true
Vips.block "VipsForeignLoadTiff", true
