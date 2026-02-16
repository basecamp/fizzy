module Search::Stemmer
  extend self

  STEMMER = Mittens::Stemmer.new

  def stem(value)
    if value.present?
      tokenize(value).join(" ")
    else
      value
    end
  end

  private
    def tokenize(value)
      tokens = []
      current_word = +""

      value.each_char do |char|
        if cjk_character?(char)
          if current_word.present?
            tokens << stem_word(current_word)
            current_word = +""
          end
          tokens << char
        elsif char =~ /[\p{L}\p{N}_]/
          current_word << char
        else
          if current_word.present?
            tokens << stem_word(current_word)
            current_word = +""
          end
        end
      end

      tokens << stem_word(current_word) if current_word.present?
      tokens
    end

    def cjk_character?(char)
      char.match?(Search::CJK_PATTERN)
    end

    def stem_word(word)
      STEMMER.stem(word.downcase)
    end
end
