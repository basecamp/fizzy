module HtmlHelper
  def format_html(html)
    fragment = Loofah::HTML5::DocumentFragment.parse(html).scrub!(AutoLinkScrubber.new)
    wrap_tables(fragment)
    fragment.to_html.html_safe
  end

  private
    def wrap_tables(fragment)
      # Collect tables first to avoid modifying the collection while iterating
      tables = fragment.css("table").to_a

      tables.each do |table|
        # Skip if already wrapped in a table-wrapper div
        parent = table.parent
        next if parent&.name == "div" && parent["class"]&.include?("table-wrapper")

        # Save a copy of the table before replacing
        table_copy = table.dup

        # Create wrapper div
        wrapper = Nokogiri::XML::Node.new("div", fragment.document)
        wrapper["class"] = "table-wrapper"
        wrapper.add_child(table_copy)

        # Replace the original table with the wrapper (which contains the copied table)
        table.replace(wrapper)
      end
    end
end
