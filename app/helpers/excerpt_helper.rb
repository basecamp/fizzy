module ExcerptHelper
  def format_excerpt(content, length: 200)
    return "" if content.blank?

    text = content.respond_to?(:to_plain_text) ? content.to_plain_text : content.to_s
    text = text.first(length * 2)
    text = text.gsub(/^>\s*(.*)$/m, '> \1')
    text = text.gsub(/^\s*[-+]\s*(.*)$/m, '• \1')
    text = text.gsub(/^\s*(\d+\.)\s*(.*)$/m, '\1 \2')
    text = text.gsub(/\s+/, " ").strip
    text.truncate(length)
  end
end
