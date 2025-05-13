class CommandsController < ApplicationController
  def index
    @commands = Current.user.commands.order(created_at: :desc).limit(20).reverse
  end

  def create
    command = parse_command(params[:command])

    if command.valid?
      if confirmed?(command)
        command.save!
        result = command.execute
        respond_with_execution_result(result)
      else
        respond_with_needs_confirmation(command)
      end
    else
      head :unprocessable_entity
    end
  end

  private
    def parse_command(string)
      command_parser.parse(string)
    end

    def command_parser
      @command_parser ||= Command::Parser.new(parsing_context)
    end

    def parsing_context
      Command::Parser::Context.new(Current.user, url: request.referrer)
    end

    def confirmed?(command)
      !command.needs_confirmation? || params[:confirmed].present?
    end

    def respond_with_execution_result(result)
      case result
      when Command::Result::Redirection
        redirect_to result.url
      when Command::Result::ChatResponse
        respond_with_chat_response(result)
      when Command::Result::InsightResponse
        respond_with_insight_response(result)
      else
        redirect_back_or_to root_path
      end
    end

    def respond_with_chat_response(result)
      command = chat_response_to_command(result)

      if confirmed?(command)
        result = command.execute
        respond_with_execution_result result
      else
        respond_with_needs_confirmation(command.commands, redirect_to: result.context_url)
      end
    end

    def respond_with_needs_confirmation(commands, redirect_to: nil)
      render json: { commands: Array(commands).collect(&:title), redirect_to: redirect_to }, status: :conflict
    end

    def chat_response_to_command(chat_response)
      context = Command::Parser::Context.new(Current.user, url: chat_response.context_url || request.referrer)
      parser = Command::Parser.new(context)
      Command::Composite.new(chat_response.command_lines.collect { parser.parse it })
    end

    def respond_with_insight_response(chat_response)
      render json: { message: chat_response.content }, status: :accepted
    end
end
