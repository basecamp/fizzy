require "zlib"

module AvatarsHelper
  AVATAR_COLORS = %w[
    #AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53
    #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E
  ]

  def avatar_background_color(user)
    AVATAR_COLORS[Zlib.crc32(user.to_param) % AVATAR_COLORS.size]
  end

  def avatar_tag(user, hidden_for_screen_reader: false, **options)
    link_to user_path(user), class: class_names("avatar btn btn--circle", options.delete(:class)), data: { turbo_frame: "_top" },
      aria: { hidden: hidden_for_screen_reader, label: user.name },
      tabindex: hidden_for_screen_reader ? -1 : nil,
      **options do
      avatar_image_tag(user)
    end
  end

  def avatar_preview_tag(user, hidden_for_screen_reader: false, **options)
    tag.span class: class_names("avatar", options.delete(:class)),
      aria: { hidden: hidden_for_screen_reader, label: user.name },
      tabindex: hidden_for_screen_reader ? -1 : nil do
      avatar_image_tag(user, **options)
    end
  end

  def avatar_image_tag(user, **options)
    image_tag user_avatar_path(user), aria: { hidden: "true" }, size: 48, title: user.name, **options
  end
end
