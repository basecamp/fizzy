# Serve a blob with its stored content type only when we recognize that type; serve everything else as binary.
#
# A blob's content type is the uploader's declaration whenever the bytes can't be identified, and an import
# carries whatever type its archive names. Some of the routes that serve a blob answer from the app's own
# origin. Rails decides the served type with a deny-list, content_types_to_serve_as_binary, and a deny-list
# only names the types someone thought of. So invert it: name the types we hand back as-is, and serve every
# other one as application/octet-stream, which X-Content-Type-Options: nosniff keeps a browser from treating
# as anything else.
#
# forcibly_serve_as_binary? is the one decision Rails reads for all of it: the served type, the forced
# attachment disposition, and the type stored with the service on upload. Disposition doesn't change for anything that
# displays today: everything inline is in content_types_allowed_inline, which is on this list.
#
# Kept as-is:
#
#   * content_types_allowed_inline: images and PDFs.
#   * audio/* and video/*: the attachment players point straight at the file.
#   * image/heic and image/heif: we convert them, and a card background or an image in the editor points
#     straight at the original.
#   * application/zip: account and user exports.
#
# Nothing else needs its type. Every other file is a download, named by its filename. Each type on this list
# must be inert as a document and as a script, and adding one is a deliberate act with a stated benefit.
module ActiveStorageServeUnknownTypesAsBinary
  ADDITIONALLY_SERVED_AS_IS = %w[ application/zip image/heic image/heif ].freeze
  AUDIO_OR_VIDEO = %r{\A(?:audio|video)/[\w!#\$&'*+.^`|~-]+\z}

  # A browser reads a comma as separating several types and takes the last, so even a comma among a kept
  # type's parameters disqualifies it. A control character can't be part of a type and has no business in a
  # header. Checked along with ascii_only?, so a non-ASCII character can't case-fold into a type on the list.
  UNSERVABLE_CHARACTER = /[[:cntrl:],]/

  private
    def forcibly_serve_as_binary?
      super || !recognized_content_type?
    end

    # Matches the media type alone, case-insensitively, so parameters and case can't carry a type past the
    # list, but the stored type goes out with its parameters intact.
    def recognized_content_type?
      declared = content_type.to_s

      declared.ascii_only? && !declared.match?(UNSERVABLE_CHARACTER) && \
        recognized_media_type?(declared.split(";").first.to_s.strip.downcase)
    end

    def recognized_media_type?(media_type)
      media_type.in?(ActiveStorage.content_types_allowed_inline) || \
        media_type.in?(ADDITIONALLY_SERVED_AS_IS) || \
        media_type.match?(AUDIO_OR_VIDEO)
    end
end

ActiveSupport.on_load :active_storage_blob do
  prepend ActiveStorageServeUnknownTypesAsBinary
end
