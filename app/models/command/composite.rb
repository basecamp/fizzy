# A composite of commands
class Command::Composite
  attr_reader :commands

  def initialize(commands)
    @commands = commands
  end

  def title
    @commands.collect(&:title).join(", ")
  end

  def execute
    result = nil
    ApplicationRecord.transaction do
      commands.each { result = it.execute }
    end
    result
  end

  def undo
    ApplicationRecord.transaction do
      undoable_commands.reverse.each(&:undo)
    end
  end

  def needs_confirmation?
    commands.any?(&:needs_confirmation?)
  end

  private
    def undoable_commands
      commands.filter(&:undoable?)
    end
end
