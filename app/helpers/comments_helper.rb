module CommentsHelper
  def comment_tag(comment, &)
    tag.div id: dom_id(comment), class: "comment flex align-start full-width",
      data: { creator_id: comment.creator_id, created_by_current_user_target: "creation" }, &
  end

  def new_comment_placeholder(card)
    if card.creator == Current.user && card.messages.comments.empty?
      "Next, add some notes, context, pictures, or video about this…"
    else
      "Type your comment…"
    end
  end
end
