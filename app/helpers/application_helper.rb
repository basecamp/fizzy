module ApplicationHelper
  def page_title_tag
    tag.title @page_title || "Fizzy"
  end

  def icon_tag(name, **options)
    tag.span class: class_names("icon icon--#{name}", options.delete(:class)), "aria-hidden": true, **options
  end

  def inline_svg(name)
    file_path = "#{Rails.root}/app/assets/images/#{name}.svg"
    return File.read(file_path).html_safe if File.exist?(file_path)
    "(not found)"
  end
end
