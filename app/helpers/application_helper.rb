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

  def back_link_to(label, url, action, **options)
    link_to url, class: "btn btn--back btn--circle-mobile", data: { controller: "hotkey", action: action }, **options do
      icon_tag("arrow-left") + tag.strong("Back to #{label}", class: "overflow-ellipsis") + tag.kbd("ESC", class: "txt-x-small hide-on-touch").html_safe
    end
  end
end
