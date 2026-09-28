# frozen_string_literal: true

# A ceiling, not a default: an operation's own limits are clamped to these, so they are sized to the most
# demanding operation — the video previewer's 120s deadline, the image transformer's 256MB file_size.
# deadline and queue_wait are seconds; memory and file_size are bytes.
HotCell.limits concurrency: 4,
               queue_size: 8,
               queue_wait: 10,
               deadline: 120,
               memory: 1536 * 1024**2,
               file_size: 256 * 1024**2
