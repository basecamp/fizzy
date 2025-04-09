module MessagesHelper
  def messages_tag(card, &)
    turbo_frame_tag dom_id(card, :messages),
      class: "comments gap center",
      style: "--card-color: <%= card.color %>",
      role: "group", aria: { label: "Messages" },
      data: {
        controller: "created-by-current-user",
        created_by_current_user_mine_class: "comment--mine"
      }, &
  end
end
