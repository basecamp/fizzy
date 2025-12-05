class Api::CommentsController < Api::BaseController
  before_action :set_card

  def create
    comment = @card.comments.create!(
      creator: Current.user,
      body: params[:body]
    )

    render json: comment_json(comment), status: :created
  end

  private
    def set_card
      @card = Current.account.cards.find_by!(number: params[:card_id])
    end

    def comment_json(comment)
      {
        id: comment.id,
        body: comment.body.to_plain_text,
        card_id: comment.card.number,
        creator: {
          id: comment.creator.id,
          name: comment.creator.name
        },
        created_at: comment.created_at.iso8601
      }
    end
end
