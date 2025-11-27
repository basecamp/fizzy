class Signup::AccountNameGenerator
  SUFFIX = "Fizzy".freeze

  attr_reader :identity, :name

  def initialize(identity:, name:)
    @identity = identity
    @name = name
  end

  def generate
    next_index = current_index + 1

    if next_index == 1
      "#{prefix} #{SUFFIX}"
    else
      "#{prefix} #{next_index.ordinalize} #{SUFFIX}"
    end
  end

  private
    def current_index
      existing_indices.max || 0
    end

    def existing_indices
      Current.without_account do
        identity.accounts.filter_map do |account|
          if account.name.match?(first_account_name_regex)
            1
          elsif match = account.name.match(nth_account_name_regex)
            match[1].to_i
          end
        end
      end
    end

    def first_account_name_regex
      @first_account_name_regex ||= /\A#{prefix}\s+#{SUFFIX}\Z/i
    end

    def nth_account_name_regex
      @nth_account_name_regex ||= /\A#{prefix}\s+(1st|2nd|3rd|\d+th)\s+#{SUFFIX}/i
    end

    def prefix
      @prefix ||= "#{first_name}'s"
    end

    def first_name
      name.strip.split(" ", 2).first
    end
end
