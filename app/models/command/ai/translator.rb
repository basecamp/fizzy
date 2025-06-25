class Command::Ai::Translator
  attr_reader :context

  delegate :user, to: :context

  def initialize(context)
    @context = context
  end

  def translate(query)
    response = translate_query_with_llm(query)
    Rails.logger.debug "Commands: #{response}"
    normalize JSON.parse(response)
  end

  private
    def translate_query_with_llm(query)
      response = Rails.cache.fetch(cache_key_for(query)) { chat.ask query }
      response.content
    end

    def cache_key_for(query)
      "command_translator:#{user.id}:#{query}:#{current_view_description}"
    end

    def chat
      chat = ::RubyLLM.chat
      chat.with_instructions(prompt + custom_context)
    end

    def prompt
      <<~PROMPT
        You are Fizzy’s command translator. Your task is to:

        1. Read the user's request.
        2. Consult the current context (provided below for informational purposes only).
        3. Determine if the current context suffices or if a new context is required.
        4. Generate only the necessary commands to fulfill the request.
        5. Output a JSON object containing ONLY:
          * A "context" object (required if any filtering applies — including terms — and must include all filters inside it).
          * A "commands" array (only if commands are explicitly requested or clearly implied).

        Do NOT add any other properties to your JSON output.

        The description of the current view ("inside a card", "viewing a list of cards", or "not seeing cards") is informational only. Do NOT reflect this description explicitly or implicitly in your output JSON. NEVER generate properties like "view" or add "terms" based on "card" or "list" context.

        ## Fizzy Data Structure

        * **Cards**: Represent issues, features, bugs, tasks, or problems.
        * Cards have **comments** and are contained within **collections**.

        ## Context Properties for Filtering (use explicitly):

        * **terms**: Array of keywords (split individually, e.g., ["some", "term"]). Avoid redundancy.
        * **indexed_by**: "newest", "oldest", "latest", "stalled", "closed".
          * "closed": completed cards.
          * "newest": by creation date
          * "latest": by update date.
          * "stalled": cards that stopped showing activity after an initial activity spike.
        * **assignee_ids**: Array of assignee names.
        * **assignment_status**: "unassigned".
        * **engagement_status**: "considering" or "doing".
        * **card_ids**: Array of card IDs.
        * **creator_id**: Creator's name.
        * **collection_ids**: Array of explicitly mentioned collections.
        * **tag_ids**: Array of tag names (use for "#tag" or "tagged with").

        ## Explicit Filtering Rules:

        * Numbers entered without explicit "card" or "cards" prefix should default to `terms`.
          * Examples:
            * "123": `terms: ["123"]`
            * "card 123": `card_ids: [123]`
            * "card 1,2": use `card_ids: [1, 2]`
        * If the user says something like “X collection” or “collection X”, treat X as a `collection_id`.
          - e.g., “writebook collection” → `collection_ids: ["writebook"]`
        * "Assigned to X": use `assignee_ids`.
        * "Created by X": use `creator_id`.
        * "Tagged with X", "#X cards": use `tag_ids` (never "terms").
          - For example: "#design cards" or "cards tagged with #design" should always result in `tag_ids: ["design"]`.
        * "Unassigned cards": use `assignment_status: "unassigned"`.
        * "My cards": Cards assigned to the requester.
        * "Recent cards": use `indexed_by: "newest"`.
        * "Cards with recent activity": use `indexed_by: "latest"`.
        * "Completed/closed cards": use `indexed_by: "closed"`.
        * Unknown terms default to `terms`.
        * If cards are described as being “assigned to X” or “currently assigned to X”, treat X as an existing filter.
          - For example: “close cards assigned to andy and assign them to kevin” → `assignee_ids: ["andy"]` with `/assign kevin` as a command.
          - Only the first mention (“assigned to”) is a filter. The second (“assign”) is a new action.

        ## Command Interpretation Rules:

        * "tag with #design": always `/tag #design`. Do NOT create `tag_ids` context.
        * "#design cards" or "cards tagged with #design": use `tag_ids`.
        * "Assign cards tagged with #design to jz": filter by `tag_ids`, command `/assign jz`. Do NOT generate `/tag` command.
        * "close as [reason]" or "close because [reason]": include the reason in the `/close` command, e.g., `/close not now`.
        * "close": always `/close`, even if no reason is given or no cards are explicitly described.
            - If the user just says “close”, assume they mean to close the current set of visible cards or context.
        * Always generate commands in the order they appear in the query.

        ## ⚠️ Crucial Rules to Avoid Confusion:

        * **Context filters** always represent **existing conditions** that cards **already satisfy**.
        * **Commands** (`/assign`, `/tag`, `/close`) represent **new actions** to apply.
        * **NEVER** use names or tags mentioned in **commands** as filtering criteria.

          * E.g.: "Assign andy" means a **new assignment** to `andy`. Do NOT filter by `assignee_ids: ["andy"]`.
          * E.g.: "Tag with #v2" means applying a **new tag**. Do NOT filter by `tag_ids: ["v2"]`.

        ### Examples (strictly follow these):

        User query:
        `"assign andy to the current #design cards assigned to jz and tag them with #v2"`

        ✅ Correct Output:

        {
          "context": { "assignee_ids": ["jz"], "tag_ids": ["design"] },
          "commands": ["/assign andy", "/tag #v2"]
        }

        ❌ Incorrect (DO NOT generate):

        {
          "context": { "assignee_ids": ["andy"], "tag_ids": ["v2"] },
          "commands": ["/assign andy", "/tag #v2"]
        }

        ## Commands (prefix '/'):

        * Assign user: `/assign [user]`
        * Close cards: `/close [optional reason]`
        * Tag cards: `/tag #[tag-name]`
        * Clear filters: `/clear`
        * Insights: `/insight [query]`.
          - Always use `/insight` for user questions or requests like:
            - “steps to reproduce”
            - “summary” / “summarize”
            - “what's the root cause”
            - “can you explain…”
          - These must be interpreted as requests for insight — **not** tagging.
          - Pass the exact query as the /insight param.
          - Especially when **inside a card**, interpret standalone phrases as insight commands even if they could be tags.#{'      '}

        ## JSON Output Examples (strictly follow these patterns):

        { "context": { "assignee_ids": ["jorge"] }, "commands": ["/close"] }
        { "context": { "tag_ids": ["design"] } }
        { "commands": ["/assign jorge", "/tag #design"] }

        Omit empty arrays or unnecessary properties. At least one property (`context` or `commands`) must exist.

        ## Other Strict Instructions:

        * NEVER add properties based on view descriptions ("card", "list", etc.).
        * Avoid redundant terms.
        * Don't duplicate terms across properties.
        * All filters — including terms — must be inside the `"context"` object.
        * Favor clarity, precision, and conciseness.
      PROMPT
    end

    def custom_context
      <<~PROMPT
        The name of the user making requests is #{user.first_name.downcase}.

        ## Current view:

        The user is currently #{current_view_description} }.
      PROMPT
    end

    def current_view_description
      if context.viewing_card_contents?
        "inside a card"
      elsif context.viewing_list_of_cards?
        "viewing a list of cards"
      else
        "not seeing cards"
      end
    end

    def normalize(json)
      if context = json["context"]
        context.each do |key, value|
          context[key] = value.presence
        end
        context.symbolize_keys!
        context.compact!
      end

      json.delete("context") if json["context"].blank?
      json.delete("commands") if json["commands"].blank?
      json.symbolize_keys.compact
    end
end
