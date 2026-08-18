# frozen_string_literal: true

# Loaded when the cell boots, before any operation.
#
# These are a ceiling, not a default: an operation's own limits are clamped to them, so these numbers only
# ever take away. They are sized to the most demanding operation this cell carries — the video previewer's
# 120s deadline, the image transformer's 256MB file_size.
#
# deadline and queue_wait are seconds; memory and file_size are bytes.
HotCell.limits concurrency: 4,
               queue_size: 8,
               queue_wait: 10,
               deadline: 120,
               memory: 1536 * 1024**2,
               file_size: 256 * 1024**2

# The gem's 48MB is too small for a 48MP phone photo. 256MB covers every current phone.
require "active_storage/hot_cell/server/transformers/image/vips"
ActiveStorage::HotCell::Server::Transformers::Image::Vips.limits file_size: 256 * 1024**2
