module Attachments
  extend ActiveSupport::Concern

  # The variants we use must all declared here so that we can preprocess them.
  #
  # If they are not preprocessed, then Rails will attempt to transform the image on-the-fly when
  # they are first viewed, which may be on the read replica where writing to the database is not
  # allowed. Chaos will ensue if that happens.
  #
  # These variants are patched into ActionText::RichText in config/initializers/action_text.rb
  VARIANTS = {
    # vipsthumbnail used to create sized image variants has a intent setting to manage colors during
    # resize. By setting an invalid intent value the gif-incompatible intent filtering is skipped and
    # the gif can be rendered with all its frame intact.
    #
    # Only `n` is accepted as an override, using the full parameter name `intent` doesn’t work.
    #
    # This was cargo-culted from know-it-all and I imagine it may be fixed at some point.
    small: { loader: { n: -1 }, resize_to_limit: [ 800, 600 ] },
    large: { loader: { n: -1 }, resize_to_limit: [ 1024, 768 ] }
  }

  def attachments
    rich_text_record&.embeds || []
  end

  def has_attachments?
    attachments.any?
  end

  def remote_images
    @remote_images ||= rich_text_record&.body&.attachables&.grep(ActionText::Attachables::RemoteImage) || []
  end

  def has_remote_images?
    remote_images.any?
  end

  def remote_videos
    @remote_videos ||= rich_text_record&.body&.attachables&.grep(ActionText::Attachables::RemoteVideo) || []
  end

  def has_remote_videos?
    remote_videos.any?
  end

  private
    def rich_text_record
      @rich_text_record ||= begin
        association = self.class.reflect_on_all_associations(:has_one).find { it.klass == ActionText::RichText }
        public_send(association.name)
      end
    end
end
