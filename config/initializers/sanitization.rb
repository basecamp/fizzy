Rails.application.config.after_initialize do
  Rails::HTML5::SafeListSanitizer.allowed_tags.merge(%w[ s table tr td th thead tbody details summary video source ])
  Rails::HTML5::SafeListSanitizer.allowed_attributes.merge(%w[ data-turbo-frame data-lightbox-target data-lightbox-caption-value controls type width ])

  # ugh, see https://github.com/rails/rails/issues/54478 which I need to fix upstream --mike
  ActionText::ContentHelper.allowed_tags = Rails::HTML5::SafeListSanitizer.allowed_tags.to_a + [ ActionText::Attachment.tag_name, "figure", "figcaption" ] + ActionText::ContentHelper.allowed_tags.to_a
  ActionText::ContentHelper.allowed_attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a + ActionText::Attachment::ATTRIBUTES + ActionText::ContentHelper.allowed_attributes.to_a
end
