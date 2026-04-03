json.(@export, :id, :status)
json.created_at @export.created_at.utc

if @export.completed? && @export.file.attached?
  json.download_url rails_blob_url(@export.file, disposition: "attachment")
end
