module MessagesHelper
  def messages_tag(card, &)
    turbo_frame_tag dom_id(card, :messages),
      class: "comments gap center",
      style: "--card-color: #{card.color}",
      role: "group", aria: { label: "Messages" }, &
  end
end
