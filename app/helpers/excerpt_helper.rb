# rbs_inline: enabled

module ExcerptHelper
  def format_excerpt(content, length: 200)
    return "" if content.blank?

    text = content.respond_to?(:to_plain_text) ? content.to_plain_text : content.to_s
    text = text.gsub(/^>\s*(.*)$/m, '> \1')
    text = text.gsub(/^\s*[-+]\s*(.*)$/m, '• \1')
    text = text.gsub(/^\d+\.\s*(.*)$/m) { |m| m }
    text = text.gsub(/\s+/, " ").strip
    text.truncate(length)
  end
end
