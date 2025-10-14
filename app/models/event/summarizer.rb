class Event::Summarizer
  include Ai::Prompts
  include Rails.application.routes.url_helpers

  attr_reader :events

  LLM_MODEL = "gpt-5-chat-latest"

  PROMPT = <<~PROMPT
    Help me make sense of the week’s activity in a news style format with bold headlines and short summaries.
      - Pick the top items to help me see patterns and milestones that I might not pick up on by looking at each individual entry.
      - Use a conversational tone without business speak.
      - Link to the issues naturally in context when possible, *do not* mention card numbers directly.

    # Use this format:
      - A single lead headline (### heading level 3) and blurb at the top that captures the overall theme of the week.
      - Then 6 (or fewer) headlines (#### heading level 4) and blurbs for the most important stories.
      - *Do not* add <hr> elements.
      - *Do not* insert a closing summary at the end.
    Markdown link format: [anchor text](/full/path/).
      - Preserve the path exactly as provided (including the leading "/").
      - When linking to a Collection, paths should be in this format: (/[account id slug]/cards?collection_ids[]=x)
  PROMPT

  def initialize(events, prompt: PROMPT, llm_model: LLM_MODEL)
    @events = events
    @prompt = prompt
    @llm_model = llm_model
  end

  def summarized_content
    llm_response.content
  end

  def cost
    Ai::UsageCost.from_llm_response(llm_response)
  end

  def summarizable_content
    join_prompts events.collect(&:to_prompt)
  end

  private
    attr_reader :prompt, :llm_model

    MAX_TOKENS = 125000

    def llm_response
      @llm_response ||= chat.ask Ai::Tokenizer.truncate(llm_query, max_input_tokens: MAX_TOKENS, model: llm_model)
    end

    def llm_query
      join_prompts("Summarize the following content:", summarizable_content)
    end

    def chat
      chat = RubyLLM.chat(model: llm_model)
      chat.with_instructions(join_prompts(prompt, domain_model_prompt, user_data_injection_prompt))
    end
end
