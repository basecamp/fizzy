module ApplicationHelper
  def page_title_tag
    account_name = if Current.account && Current.session&.identity&.users&.many?
      Current.account&.name
    end
    tag.title [ @page_title, account_name, "Fizzy" ].compact.join(" | ")
  end

  def icon_tag(name, **options)
    tag.span class: class_names("icon icon--#{name}", options.delete(:class)), "aria-hidden": true, **options
  end

  def inline_svg(name)
    file_path = "#{Rails.root}/app/assets/images/#{name}.svg"
    return File.read(file_path).html_safe if File.exist?(file_path)
    "(not found)"
  end

  def back_link_to(label, url, action, **options)
    link_to url, class: "btn btn--back", data: { controller: "hotkey", action: action }, **options do
      icon_tag("arrow-left") + tag.strong("Back to #{label}", class: "overflow-ellipsis") + tag.kbd("ESC", class: "txt-x-small hide-on-touch").html_safe
    end
  end

  def admin_nav_link(label, url, icon: nil, **options)
    classes = class_names("btn btn--back", options.delete(:class))
    
    link_to url, class: classes, **options do
      content = []
      content << icon_tag(icon) if icon
      content << tag.strong(label, class: "overflow-ellipsis")
      safe_join(content)
    end
  end
  
  def admin_header_content
    if request.path.start_with?("/admin/jobs")
      render("admin/navigation")
    end
  end
end
