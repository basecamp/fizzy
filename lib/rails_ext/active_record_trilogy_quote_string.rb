# Match mysql2 behavior
module ActiveRecordTrilogyQuoteString
  def quote_string(string)
    unless string.encoding == Encoding::UTF_8 || string.encoding == Encoding::BINARY || @config[:encoding] == "binary"
      string = string.encode(Encoding::UTF_8)
    end

    super
  end
end

ActiveSupport.on_load :active_record_trilogyadapter do
  prepend ActiveRecordTrilogyQuoteString
end
