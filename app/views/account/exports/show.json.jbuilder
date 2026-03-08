json.(@export, :id, :status)
json.created_at @export.created_at.utc
json.download_url(@export.completed? && @export.file.attached? ? rails_blob_url(@export.file, disposition: "attachment") : nil)
