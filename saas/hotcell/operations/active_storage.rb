# frozen_string_literal: true

# The five Active Storage operations this cell serves, required one file at a time rather than through the
# gem's entry point. That entry point also loads the ImageMagick and Poppler operations, whose tools this
# image deliberately does not carry, and a cell should advertise only what it can actually do.
#
# All five ship from the first build, including the ones the rollout reaches last. The application's
# HOTCELL_ACTIVE_STORAGE switch is what stages the traffic; staging the image instead would make every
# rollout step an accessory rebuild and reboot.

require "active_storage/hot_cell/server/transformers/image/vips"
require "active_storage/hot_cell/server/analyzers/image/vips"
require "active_storage/hot_cell/server/analyzers/media/ffprobe"
require "active_storage/hot_cell/server/previewers/pdf/mutool"
require "active_storage/hot_cell/server/previewers/video/ffmpeg"
