class Command::ChatQuery < Command
  store_accessor :data, :query, :params

  def title
    "Chat query '#{query}'"
  end

  def execute
    response = chat.ask query
    generated_commands = replace_names_with_ids(JSON.parse(response.content)).tap do |commands|
      Rails.logger.info "*** #{commands}"
    end
    build_chat_response_with generated_commands
  end

  private
    def chat
      chat = RubyLLM.chat
      chat.with_instructions(prompt)
    end

    # TODO:
    #   - Don't generate initial /search if not requested. "Assign to JZ" should
    def prompt
      <<~PROMPT
        You are a helpful assistant that translates natural language into one or more commands that Fizzy understand.

        Fizzy supports the following commands:

        - Assign users to cards: /assign [user]. E.g: "/assign kevin"
        - Close cards: /close [optional reason]. E.g: "/close" or "/close not now"
        - Tag cards: /tag [tag-name]. E.g: "/tag performance"
        - Get insight about cards: /insight [query]. Use this as the default command to satisfy questions and requests
            about cards. This relies on /search. Example: "/insight summarize performance issues".
        - Search cards based on certain keywords: /search. See how this works below. E.g: "/search meetup montreal". IMPORTANT: There can
            only be one /search command in the response.

        If you need to filter a certain set of cards, you can use the /search command to filter.

        The /search command (and only this command) supports the following parameters:

          - assignment_status: can be "unassigned". Only include if asking for unassigned cards explicitly
          - indexed_by: can be "newest", "oldest", "latest", "stalled", "closed"
          - engagement_status: can be "considering" or "doing"
          - card_ids: a list of card ids
          - assignee_ids: a list of assignee names
          - creator_id: the name of a person
          - collection_ids: a list of collection names. Cards are contained in collections. Don't use unless mentioning
              specific collections.
          - tag_ids: a list of tag names.
          - terms: a list of terms to search for. Use this option to refine searches based on further keyword-based
             queries.

        So each command will be a JSON object like:

        { command: "/close" }

        The /search command can also contain additional params:

        { command: "/search", indexed_by: "closed", collection_ids: [ "Writebook", "Design" ] }

        Notice that there are similar commands to filter and act on cards (e.g: filter by assignee or assign cards). Favor
        filtering/queries for commands like "cards assigned to someone".

        For example, to assign a card, you invoke `assign kevin`. For insight about "something", you invoke "/insight something".

        Important:

        - When using the /insight command, consider adding first a /search command that filters out the relevant cards to answer 
        the question. If there are relevant keywords to filter, pass those to /search but avoid passing generic ones. Then, reformulate
        pass the query itself VERBATIM to /insight as in "/insight <original query>", no additional keys in the JSON.
        - Only add an /insight command is there is a specific question about the data. Some requests are just about searching some
        cards. Those are fine.
        - Sometimes, the current context is a given card or the set of cards in the screen. In that case, there is no need to add a
        /search command. Assume that's the case if it's missing any description of the the set of cards required. E.g: just "summarise"
        or "this card".
        - A response can only contain ONE /search command AT MOST.
        - A response can only contain ONE /insight command AT MOST.
        - Unless asking for explicit filtering, always prefer /insight over /search. When asking about "cards" with properties that can
        be satisfied with /search, then use /search.


        For example, for "summarize performance issues", the JSON could be:

          [
            {
              "command": "/search",
              "terms": ["performance"]
            },
            {
              "command": "/insight summarize performance issues"
            }
          ]


        Please combine commands to satisfy what the user needs. E.g: search with keywords and filters and then apply
        as many commands as needed. Make sure you don't leave actions mentioned in the query needs unattended.'

        The output will be in JSON. It will contain a list of commands. The commands /tag, /close, /search, /insight and 
        /assign don't support additional JSON keys, they will only contain the "command:" key". For /search, it can contain additional
        JSON keys matching the /search params described above.

        Don't generate any /search without params. Just don't add it.

        Avoid empty preambles like "Based on the provided cards". Also, prefer a natural a friendly language favoring active voice.

        Make sure to place into double quotes the strings in JSON values and that you generate valid JSON. I want a
        JSON list like [{}, {}...]

        Respond only with the JSON.
      PROMPT
    end

    def replace_names_with_ids(commands)
      commands.each do |command|
        if command["command"] == "/search"
          command["assignee_ids"] = command["assignee_ids"]&.filter_map { |name| assignee_from(name)&.id }
          command["creator_id"] = assignee_from(command["creator_id"])&.id if command["creator_id"]
          command["collection_ids"] = command["collection_ids"]&.filter_map { |name| Collection.where("lower(name) = ?", name.downcase).first&.id }
          command["tag_ids"] = command["tag_ids"]&.filter_map { |name| ::Tag.find_by_title(name)&.id }
          command.compact!
        end
      end
    end

    def assignee_from(string)
      string_without_at = string.delete_prefix("@")
      User.all.find { |user| user.mentionable_handles.include?(string_without_at) }
    end

    def build_chat_response_with(generated_commands)
      Command::Result::ChatResponse.new \
        command_lines: response_command_lines_from(generated_commands),
        context_url: response_context_url_from(generated_commands)
    end

    def response_command_lines_from(generated_commands)
      # We translate standalone /search commands as redirections to execute. Otherwise, they
      # will be excluded out from the commands to run, as they represent the context url.
      if generated_commands.size == 1
        [ "/visit #{cards_path(**generated_commands.first.without("command"))}" ]
      else
        generated_commands.filter { it["command"] != "/search" }.collect { it["command"] }
      end
    end

    def response_context_url_from(generated_commands)
      if generated_commands.size > 1 && search_command = generated_commands.find { it["command"] == "/search" }
        cards_path(**search_command.without("command"))
      end
    end
end
