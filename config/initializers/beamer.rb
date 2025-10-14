# This is a temporary shim to load the Beamer VFS prior to opening the tenanted
# databases that use it.
#
# It's here to get around the fact that the VFS needs to be registed before the
# databases are opened, so we can't rely on the normal extension loading to do
# it.
#
# We'll move this responsibility into a Beamer gem soon, at which point this
# file will be removed.

Rails.application.config.after_initialize do
  paths = [
    Rails.root.join("bin/lib/beamer.so"),
    Pathname("/usr/local/lib/beamer/beamer.so")
  ]

  paths.each do |beamer_extension_path|
    if beamer_extension_path.exist?
      db = SQLite3::Database.new ":memory:"
      db.enable_load_extension(true)
      db.load_extension(beamer_extension_path)
      break
    end
  end
end
