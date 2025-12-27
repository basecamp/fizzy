module MessagesHelper
  def messages_tag(card, &)
    turbo_frame_tag dom_id(card, :messages),
      class: "comments gap center",
      style: "--card-color: #{card.color}",
      role: "group",
      aria: { label: "Messages" },
      data: { controller: "toggle-class", toggle_class_toggle_class: "comments--system-expanded" }, &
  end
end
