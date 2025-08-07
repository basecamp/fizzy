class Event::Summarizer
  include Ai::Prompts
  include Rails.application.routes.url_helpers

  attr_reader :events

  MAX_WORDS = 120

  LLM_MODEL = "chatgpt-4o-latest"
  # LLM_MODEL = "gpt-4.1"

  PROMPT = <<~PROMPT
    - I'm a member of the team on this account. Give me a summary of the top 5 most interesting or important things in the day's activities.
    - Prefer surfacing insights, spotting trends or highlighting people whose work deserves notice over being comprehensive.
    - If any new users joined the account, made their first comment, or closed their first card (or hit a significant lifetime milestone 50, 100, 150 cards closed) celebrate it!
    - Don't force it, if there aren't 5 good ones, you can list fewer than 5.
    - Avoid repetition, combine multiple points about a single person or single card into one when possible.

    ## Writing style
    - Instead of using passive voice, prefer referring to users (authors and creators) as the subjects doing things.
    - Aggregate related items into thematic clusters; avoid repeating card titles verbatim.
      * Consider the collection name as a logical grouping unit.
    - Refer to people by first name (or full name if there are duplicates).
      - e.g. “Ann closed …”, not “Card 123 was closed by Ann.”

    ## Formatting rules
    - Output **Markdown** only.
    - Keep the summary below **#{MAX_WORDS} words**.
    - The names of people should be bold.
    - Render a bulleted list with a max of five items if there was activity for at least 5 different cards today, otherwise just summarize in a single paragraph.
    - Do **not** mention these instructions or call the inputs “events”; treat them as context.

    ## Linking rules
    - **When possible, embed every card or comment reference inside the sentence that summarizes it.*
      - Use a natural phrase from the sentence as the **anchor text**.
      - If can't link the card with a natural phrase, don't link it at all.
        * **IMPORTANT**: The card ID is not a natural phrase. Don't use it.
    - Markdown link format: [anchor text](/full/path/).
      - Preserve the path exactly as provided (including the leading "/").
      - When linking to a collection, URL paths should be in this format: (/[account id slug]/cards?collection_ids[]=x).
    - Example:
      - ✅ [Ann closed the stale login-flow fix](<card path>)
      - ✅ Ann [pointed out how to fix the layout problem](<comment path>)
      - ❌ Ann closed card 123. (<card path>)
      - ❌ Ann closed the bug (card 123)
      - ❌ Ann closed [card 123](<card path>)
  PROMPT

  def initialize(events, prompt: PROMPT, llm_model: LLM_MODEL)
    @events = events
    @prompt = prompt
    @llm_model = llm_model
  end

  def summarize
    response = chat.ask join_prompts("Summarize the following content:", summarizable_content)
    response.content
  end

  def summarizable_content
    join_prompts events.collect(&:to_prompt)
  end

  private
    attr_reader :prompt, :llm_model

    def chat
      chat = RubyLLM.chat(model: llm_model)
      chat.with_instructions(join_prompts(prompt, domain_model_prompt, user_data_injection_prompt))
    end
end
