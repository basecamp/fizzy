# frozen_string_literal: true

# Loaded when the cell boots, before any operation.
#
# These are a ceiling, not a default: an operation's own limits are clamped to them, so these numbers only
# ever take away. They are sized to the most demanding operation this cell carries, which is the video
# previewer — it asks for a 120s deadline and a 128MB output, and the worked example in the hotcell
# DEPLOYMENT.md configures 30s and 48MB. Copy that example and video previews arrive as `killed`, on video
# only. The image operations declare 30s and 48MB for themselves and are unaffected by the headroom.
#
# deadline and queue_wait are seconds; memory and file_size are bytes.
HotCell.limits concurrency: 4,
               queue_size: 8,
               queue_wait: 10,
               deadline: 120,
               memory: 1536 * 1024**2,
               file_size: 128 * 1024**2
