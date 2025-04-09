module AccessesHelper
  def access_menu_tag(collection, &)
    tag.menu class: [ "flex flex-column gap margin-none pad txt-medium", { "toggler--toggled": collection.all_access? } ], data: {
      controller: "filter toggle-class",
      filter_active_class: "filter--active", filter_selected_class: "selected",
      toggle_class_toggle_class: "toggler--toggled" }, &
  end

  def access_toggles_for(users, selected:)
    render partial: "collections/access_toggle",
      collection: users, as: :user,
      locals: { selected: selected },
      cached: ->(user) { [ user, selected ] }
  end

  def access_involvement_advance_button(collection, user)
    access = collection.access_for(user)

    turbo_frame_tag dom_id(collection, :involvement_button) do
      button_to collection_involvement_path(collection), method: :put,
          aria: { labelledby: dom_id(collection, :involvement_label) },
          class: [ "btn", { "btn--reversed": access.involvement == "watching" || access.involvement == "everything" } ],
          params: { involvement: next_involvement(access.involvement) },
          title: involvement_access_label(collection, access.involvement) do
        icon_tag("notification-bell-#{access.involvement.dasherize}") +
          tag.span(involvement_access_label(collection, access.involvement), class: "for-screen-reader", id: dom_id(collection, :involvement_label))
      end
    end
  end

  private
    def next_involvement(involvement)
      order = %w[ everything watching access_only ]
      order[(order.index(involvement.to_s) + 1) % order.size]
    end

    def involvement_access_label(collection, involvement)
      case involvement
      when "access_only"
        "Notifications are off for #{collection.name}"
      when "everything"
        "Notifying me about everything in #{collection.name}"
      when "watching"
        "Notifying me only about @mentions and new items in #{collection.name}"
      end
    end
end
