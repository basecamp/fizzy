module My::MenuHelper
  def jump_field_tag
    text_field_tag :search, nil,
      type: "search",
      role: "combobox",
      placeholder: "Type to jump to a board, person, place, or tag…",
      class: "input input--transparent txt-small",
      autofocus: true,
      autocorrect: "off",
      autocomplete: "off",
      aria: { activedescendant: "" },
      data: {
        "1p-ignore": "true",
        filter_target: "input",
        nav_section_expander_target: "input",
        navigable_list_target: "input",
        action: "input->filter#filter" }
  end

  def my_menu_board_item(board)
    my_menu_item("board", board) do
      link_to(tag.span(board.name, class: "overflow-ellipsis"), board, class: "popup__btn btn")
    end
  end

  def my_menu_tag_item(the_tag)
    my_menu_item("tag", tag) do
      link_to(tag.span(class: "overflow-ellipsis") do
        tag.span("##{the_tag.title}", class: "visually-hidden") + the_tag.title
      end, cards_path(tag_ids: [ the_tag ]), class: "popup__btn btn", title: "##{the_tag.title}")
    end
  end

  def my_menu_user_item(user)
    my_menu_item("person", user) do
      link_to(tag.span(user.name, class: "overflow-ellipsis"), user, class: "popup__btn btn")
    end
  end

  def my_menu_filter_item(filter)
    my_menu_item("bookmark", filter) do
      link_to(cards_path(filter_id: filter.id), class: "popup__btn btn") do
        tag.div(class: "txt-tight-lines min-width txt-small overflow-ellipsis") do
          tag.div(tag.strong(filter.boards_label)) +
          tag.div(filter.summary, class: "txt-capitalize")
        end
      end
    end
  end

  def my_menu_item(item, record)
    tag.li(class: "popup__item", data: { filter_target: "item", navigable_list_target: "item", id: "filter-#{item}-#{record.id}" }) do
      icon_tag(item, class: "popup__icon") + yield
    end
  end
end
