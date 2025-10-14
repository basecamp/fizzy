class Ai::ListCardsTool < Ai::Tool
  description <<-MD
    Lists all cards accessible by the current user.
    The response is paginated so you may need to iterate through multiple pages to get the full list.
    URLs are valid if they are just a path - don't change them!
    Each card object has the following fields:
    - id [Integer, not null]
    - title [String, not null] - The title of the card
    - status [String, not null] - Enum of "creating", "draft" and "published"
    - last_active_at [DateTime, not null] - The last time the card was updated
    - collection_id [Integer, not null] - The ID of the collection this card belongs to
    - stage [Object, not null] - The stage this card is in, with fields:
      - id [Integer, not null]
      - name [String, not null]
    - creator [Object, not null] - The user who created the card, with fields:
      - id [Integer, not null]
      - name [String, not null]
    - assignees [Array of Objects, not null] - The users assigned to the card, each with fields:
      - id [Integer, not null]
      - name [String, not null]
  MD

  param :page,
    type: :string,
    desc: "Which page to return. Leave blank to get the first page",
    required: false
  param :query,
    type: :string,
    desc: "If provided, will perform a semantic search by embeddings and return only matching cards",
    required: false
  param :ordered_by,
    type: :string,
    desc: "Can be either id, created_at or last_active_at followed by ASC or DESC - e.g. `created_at DESC`",
    required: false
  param :ids,
    type: :string,
    desc: "If provided, will return only cards with the given IDs (comma-separated)",
    required: false
  param :collection_ids,
    type: :string,
    desc: "If provided, will return only cards for the specified collections (comma-separated)",
    required: false
  param :golden,
    type: :boolean,
    desc: "If provided, will return only golden cards",
    required: false
  param :created_after,
    type: :string,
    desc: "If provided, will return only cards created on or after the given ISO timestamp",
    required: false
  param :created_before,
    type: :string,
    desc: "If provided, will return only cards created on or before the given ISO timestamp",
    required: false
  param :last_active_after,
    type: :string,
    desc: "If provided, will return only card that were last active on or after the given ISO timestamp",
    required: false
  param :last_active_before,
    type: :string,
    desc: "If provided, will return only card that were last active on or before the given ISO timestamp",
    required: false

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def execute(**params)
    cards = Card
      .where(collection: user.collections)
      .published
      .with_rich_text_description
      .includes(:column, :creator, :assignees, :goldness, :collection)

    cards = Filter.new(scope: cards, filters: params).filter

    ordered_by = OrderClause.parse(
      params[:ordered_by],
      defaults: { id: :desc },
      permitted_columns: %w[id created_at last_active_at]
    )

    # TODO: The serialization here is temporary until we add an API,
    # then we can re-use the jbuilder views and caching from that
    paginated_response(cards, page: params[:page], ordered_by: ordered_by.to_h) do |card|
      card_attributes(card)
    end
  end

  private
    def card_attributes(card)
      {
        id: card.id,
        title: card.title,
        status: card.status,
        last_active_at: card.last_active_at,
        collection_id: card.collection_id,
        golden: card.golden?,
        column: card.column.as_json(only: [ :id, :name ]),
        creator: card.creator.as_json(only: [ :id, :name ]),
        assignees: card.assignees.as_json(only: [ :id, :name ]),
        description: card.description.to_plain_text.truncate(1000),
        url: card_url(card)
      }
    end
end
