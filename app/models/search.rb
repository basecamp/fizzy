module Search
  CJK_PATTERN = /\p{Han}|\p{Hiragana}|\p{Katakana}|\p{Hangul}/

  def self.table_name_prefix
    "search_"
  end
end
