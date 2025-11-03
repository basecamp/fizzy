#
#  see https://app.box-car.com/5986089/collections/7/cards/1302
#
#  Large previewable uploads may take longer than the "pin reads" interval. So we pick a small-ish
#  number and turn off previews for anything larger, at least until we can come up with a permanent
#  solution.
#
module ActiveStorageBlobPreviewable
  MAX_PREVIEWABLE_SIZE = 16.megabytes # this is pretty arbitrary, feel free to adjust

  def previewable?
    super && self.byte_size <= MAX_PREVIEWABLE_SIZE
  end
end

ActiveSupport.on_load :active_storage_blob do
  prepend ::ActiveStorageBlobPreviewable
end
