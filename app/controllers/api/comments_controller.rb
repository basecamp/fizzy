class Api::CommentsController < Api::BaseController
  before_action :set_card

  def index
    comments = @card.comments.chronologically.preloaded
      .includes(mentions: :mentionee, card_links: :card, creator: :identity)
    render json: comments.map { |comment| comment_json(comment) }
  end

  def create
    raise ArgumentError, "body parameter is required" unless params[:body].present?
    
    # Disable callbacks before creation to prevent double execution
    # We'll create mentions and card_links synchronously instead
    Comment.skip_callback(:commit, :after, :create_mentions_later, raise: false)
    Comment.skip_callback(:commit, :after, :create_card_links_later, raise: false)
    
    begin
      comment = @card.comments.create!(
        creator: Current.user,
        body: params[:body]
      )

      # Create mentions and card_links synchronously for API responses
      # (normally done asynchronously via jobs, but we need them immediately)
      comment.create_mentions(mentioner: Current.user)
      comment.create_card_links(creator: Current.user)
    ensure
      # Re-enable callbacks for future operations
      Comment.set_callback(:commit, :after, :create_mentions_later)
      Comment.set_callback(:commit, :after, :create_card_links_later)
    end

    # Reload with associations to avoid N+1 queries
    comment = Comment.preloaded
      .includes(mentions: :mentionee, card_links: :card, creator: :identity)
      .find(comment.id)

    render json: comment_json(comment), status: :created
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end

    def comment_json(comment)
      {
        id: comment.id,
        body: comment.body&.to_plain_text,
        body_plain_text: comment.body&.to_plain_text,
        card_id: comment.card.number,
        creator: {
          id: comment.creator.id,
          name: comment.creator.name
        },
        mentions: comment.mentions.map do |mention|
          mentionee = mention.mentionee
          {
            user_id: mentionee.id,
            username: mentionee.identity&.email_address&.split("@")&.first || mentionee.name.downcase.gsub(/\s+/, "."),
            name: mentionee.name,
            email: mentionee.identity&.email_address
          }
        end,
        card_links: comment.card_links.map do |card_link|
          {
            card_id: card_link.card.number,
            title: card_link.card.title
          }
        end,
        created_at: comment.created_at.iso8601
      }
    end
end
