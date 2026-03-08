json.(@export, :id, :status, :created_at)
json.download_url(@export.completed? && @export.file.attached? ? rails_blob_url(@export.file, disposition: "attachment") : nil)
