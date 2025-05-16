class Command::Ai::Translator
  attr_reader :context

  delegate :user, to: :context

  def initialize(context)
    @context = context
  end

  def translate(query)
    response = translate_query_with_llm(query)
    Rails.logger.info "*** Commands: #{response}"
    normalize JSON.parse(response)
  end

  private
    def translate_query_with_llm(query)
      response = Rails.cache.fetch(cache_key_for(query)) { chat.ask query }
      response.content
    end

    def cache_key_for(query)
      "command_translator:#{user.id}:#{query}:#{context_description}"
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

           * A "context" object (only if a new filtering context is required, strictly following defined properties below).
           * A "commands" array (only if commands are explicitly requested or clearly implied).

        Do NOT add any other properties to your JSON output.

        The description of the current view ("inside a card", "viewing a list of cards", or "not seeing cards") is informational only. Do NOT reflect this description explicitly or implicitly in your output JSON. NEVER generate properties like "view" or add "terms" based on "card" or "list" context.

        ## Fizzy Data Structure

        * **Cards**: Represent issues, features, bugs, tasks, or problems.
        * Cards have **comments** and are contained within **collections**.

        ## Context Properties for Filtering (use explicitly):

        * **terms**: Array of keywords (split individually, e.g., \["some", "term"]). Avoid redundancy.
        * **indexed\_by**: "newest", "oldest", "latest", "stalled", "closed".

          * "closed": completed cards.
          * "newest": by creation date, "latest": by update date.
        * **assignee\_ids**: Array of assignee names.
        * **assignment\_status**: "unassigned".
        * **engagement\_status**: "considering" or "doing".
        * **card\_ids**: Array of card IDs.
        * **creator\_id**: Creator's name.
        * **collection\_ids**: Array of explicitly mentioned collections.
        * **tag\_ids**: Array of tag names (use for "#tag" or "tagged with").

        ## Explicit Filtering Rules:

        * "Assigned to X": use `assignee_ids`.
        * "Created by X": use `creator_id`.
        * "Tagged with X", "#X cards": use `tag_ids` (never "terms").
          - For example: "#design cards" or "cards tagged with #design" should always result in `tag_ids: ["design"]`.
        * "Unassigned cards": use `assignment_status: "unassigned"`.
        * "My cards": Cards assigned to the requester.
        * "Recent cards": use `indexed_by: "newest"`.
        * "Cards with recent activity": use `indexed_by: "latest"`.
        * "Completed/closed cards": use `indexed_by: "closed"`.
        * Unknown terms: default to `terms`.

        ## Command Interpretation Rules:

        * "tag with #design": always `/tag #design`. Do NOT create `tag_ids` context.
        * "#design cards" or "cards tagged with #design": use `tag_ids`.
        * "Assign cards tagged with #design to jz": filter by `tag_ids`, command `/assign jz`. Do NOT generate `/tag` command.

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

        * Assign user: `/assign [user]` (e.g., `/assign kevin`).
        * Close cards: `/close [optional reason]` (e.g., `/close`, `/close not now`).
        * Tag cards: `/tag #[tag-name]` (e.g., `/tag #design`).
        * Clear filters: `/clear`.
        * Insights (mandatory if question asked or explicitly requested): `/insight [query]`.
          - Always use `/insight` for queries like "steps to reproduce", "summarize", or similar queries that clearly request insight about cards,
            especially when "inside a card". Pass the original query as the argument.

        ## JSON Output Examples (strictly follow these patterns):

        { "context": { "assignee_ids": ["jorge"] }, "commands": ["/close"] }
        { "context": { "tag_ids": ["design"] } }
        { "commands": ["/assign jorge", "/tag #design"] }

        Omit empty arrays or unnecessary properties. At least one property (`context` or `commands`) must exist.

        ## Other Strict Instructions:

        * NEVER add properties based on view descriptions ("card", "list", etc.).
        * Avoid redundant terms.
        * Don't duplicate terms across properties.
        * Favor clarity, precision, and conciseness.
      PROMPT
    end

    def custom_context
      <<~PROMPT
        The name of the user making requests is #{user.first_name.downcase}.

        ## Current view:

        The user is currently #{context_description} }.
      PROMPT
    end

    def context_description
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
