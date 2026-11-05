# Fizzy serves files by redirecting to the storage service, never by streaming them through the app. The
# engine still draws the proxy routes, and a file served from them comes from the app's own origin with a
# cache lifetime of a hundred years. Nothing links to them, so they answer 404 before looking up the blob.
#
# ActiveStorage::Authorize stays on these controllers, so taking this out can't open them to everyone.
Rails.application.config.to_prepare do
  [ ActiveStorage::Blobs::ProxyController, ActiveStorage::Representations::ProxyController ].each do |controller|
    controller.prepend_before_action { head :not_found }
  end
end
