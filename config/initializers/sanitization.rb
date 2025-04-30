Rails.application.config.after_initialize do
  Rails::HTML5::SafeListSanitizer.allowed_tags.merge(%w[ s table tr td th thead tbody details summary video source])
  Rails::HTML5::SafeListSanitizer.allowed_attributes.merge(%w[ data-turbo-frame controls type width data-action data-lightbox-target data-lightbox-url-value ])
end
