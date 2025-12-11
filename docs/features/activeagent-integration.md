# ActiveAgent Integration for Fizzy

## Overview

This document outlines the integration of ActiveAgent-based AI assistants into Fizzy's rich text editor, inspired by the Writebook implementation pattern. The goal is to add writing, file analysis, and research assistants accessible from the markdown/rich text toolbar.

## Architecture

### ActiveAgent Framework

ActiveAgent is a Rails framework (similar to ActionMailer) for building AI agents. Key concepts:

- **Agents** (`app/agents/`): Ruby classes that define AI interactions
- **Prompts**: ERB templates that define the AI instructions
- **Generation Providers**: Adapters for OpenAI, Anthropic, Ollama, etc.
- **Actions**: Tool-calling capabilities for agents

### File Structure

```
app/
├── agents/
│   ├── application_agent.rb          # Base agent class
│   ├── writing_assistant_agent.rb    # Text improvement assistant
│   ├── file_analysis_agent.rb        # Document/image analysis
│   └── research_agent.rb             # Web research assistant
├── views/
│   ├── application_agent/
│   │   └── instructions.text.erb     # Default system instructions
│   ├── writing_assistant_agent/
│   │   ├── instructions.text.erb     # Writing-specific instructions
│   │   ├── improve.text.erb          # Improve text prompt template
│   │   ├── summarize.text.erb        # Summarize prompt template
│   │   └── expand.text.erb           # Expand content template
│   ├── file_analysis_agent/
│   │   ├── instructions.text.erb
│   │   └── analyze.text.erb
│   └── research_agent/
│       ├── instructions.text.erb
│       └── research.text.erb
├── views/layouts/
│   └── agent.text.erb                # Layout for agent prompts
├── controllers/
│   └── ai/
│       ├── writing_controller.rb     # Endpoint for writing assistance
│       ├── analysis_controller.rb    # Endpoint for file analysis
│       └── research_controller.rb    # Endpoint for research
├── javascript/controllers/
│   └── ai_assistant_controller.js    # Stimulus controller for UI
config/
└── active_agent.yml                  # Provider configuration
```

## Implementation Plan

### Phase 1: Foundation

1. **Create config/active_agent.yml**
   - Configure OpenAI as primary provider
   - Support for Anthropic as alternative
   - Environment-specific settings

2. **Create ApplicationAgent**
   - Base class with common configuration
   - Streaming support
   - Error handling

3. **Create agent layout**
   - Simple text layout for prompts

### Phase 2: Writing Assistant

The writing assistant helps users improve their card descriptions and comments:

```ruby
class WritingAssistantAgent < ApplicationAgent
  generate_with :openai, model: "gpt-4o-mini"

  def improve
    prompt(message: params[:text])
  end

  def summarize
    prompt(message: params[:text])
  end

  def expand
    prompt(message: params[:text])
  end
end
```

**Features:**
- Improve clarity and grammar
- Summarize long text
- Expand bullet points into prose
- Adjust tone (professional, casual)

### Phase 3: File Analysis Agent

Analyzes documents and images attached to cards:

```ruby
class FileAnalysisAgent < ApplicationAgent
  generate_with :openai, model: "gpt-4o"  # Vision capable

  def analyze
    prompt(
      message: params[:message] || "Analyze this content",
      image_data: @image_data,
      file_data: @file_data
    )
  end
end
```

**Features:**
- Extract text from images (OCR)
- Summarize PDF documents
- Describe image contents
- Extract structured data

### Phase 4: Research Agent

Helps gather context for cards:

```ruby
class ResearchAgent < ApplicationAgent
  generate_with :openai, model: "gpt-4o-mini"

  def research
    prompt(message: params[:query])
  end
end
```

**Features:**
- Generate research summaries
- Find related topics
- Suggest next steps

### Phase 5: UI Integration

**Toolbar Integration:**

Add AI assistant buttons to the Lexxy rich text toolbar using `<lexxy-prompt>` elements or custom buttons:

```erb
<%# In rich_text_helper.rb %>
def ai_assistant_prompt
  content_tag "lexxy-ai-assistant", "",
    "data-controller": "ai-assistant",
    "data-ai-assistant-url-value": ai_writing_path
end
```

**Stimulus Controller:**

```javascript
// ai_assistant_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  async improve() {
    const selection = this.getSelectedText()
    const response = await this.callAgent("improve", { text: selection })
    this.replaceSelection(response)
  }

  async summarize() {
    // Similar pattern
  }
}
```

## Routes

```ruby
# config/routes.rb
namespace :ai do
  resource :writing, only: [] do
    post :improve
    post :summarize
    post :expand
  end

  resource :analysis, only: [] do
    post :analyze
  end

  resource :research, only: [] do
    post :research
  end
end
```

## Security Considerations

1. **Rate Limiting**: Implement per-user rate limits
2. **Content Filtering**: Ensure AI doesn't generate harmful content
3. **Cost Control**: Monitor API usage per account
4. **Data Privacy**: Don't send sensitive data to external APIs
5. **Authentication**: Require logged-in users for AI features

## Configuration

```yaml
# config/active_agent.yml
openai: &openai
  service: "OpenAI"
  access_token: <%= Rails.application.credentials.dig(:openai, :access_token) %>

anthropic: &anthropic
  service: "Anthropic"
  access_token: <%= Rails.application.credentials.dig(:anthropic, :access_token) %>

development:
  openai:
    <<: *openai
    model: "gpt-4o-mini"
    temperature: 0.7
  anthropic:
    <<: *anthropic
    model: "claude-3-5-sonnet-20241022"

production:
  openai:
    <<: *openai
    model: "gpt-4o-mini"
    temperature: 0.7
```

## Future Enhancements

1. **Streaming responses** for real-time feedback
2. **Context-aware suggestions** based on board/project
3. **Custom prompts** per account/board
4. **Usage analytics** for AI features
5. **Offline/local model support** via Ollama

## References

- ActiveAgent gem: `/Users/justinbowen/Documents/GitHub/activeagents`
- Demo app: `/Users/justinbowen/Documents/GitHub/active-agents`
- Fizzy rich text: Lexxy gem with `<lexxy-prompt>` elements
