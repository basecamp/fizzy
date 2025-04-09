#!/usr/bin/env ruby

require "find"
require "active_support/core_ext/string" # for camelize

RENAME_RULES = {
  "bubble" => "card",
  "popped" => "closed",
  "poppable" => "closeable",
  "pop" => "closure",
  "bucket" => "collection"
}

EXTENSIONS = %w[.rb .yml .html .js .css .erb]
EXCLUDED_DIRS = %w[db .git script/renaming vendor/javascript]

# Helper to build replacement regex patterns respecting case and separators
def build_patterns(from, to)
  boundary = "(?<=\\A|[^a-zA-Z0-9])#{from}(?=[^a-zA-Z0-9]|\\z)"
  camel = from.camelize
  camel_plural = camel.pluralize
  underscore_plural = from.pluralize.underscore
  dasherized_plural = underscore_plural.dasherize

  [
    # Match lowercase boundary-delimited
    [ /#{boundary}/, to ],
    # Match capitalized version (e.g., Bubble => Card)
    [ /(?<![a-zA-Z0-9])#{from.capitalize}(?![a-z])/, to.capitalize ],
    # Match all-uppercase
    [ /(?<![a-zA-Z0-9])#{from.upcase}(?![A-Z])/, to.upcase ],
    # Match CamelCase and plural CamelCase
    [ /(?<![a-zA-Z0-9])#{camel}(?![a-z])/, to.camelize ],
    [ /(?<![a-zA-Z0-9])#{camel_plural}(?![a-z])/, to.camelize.pluralize ],
    # Match lowerCamelCase
    [ /(?<![a-zA-Z0-9])#{from.camelize(:lower)}(?![a-z])/, to.camelize(:lower) ],
    # Match underscore and dashed plural forms (e.g. bubbles(:logo) => cards(:logo))
    [ /(?<![a-zA-Z0-9])#{underscore_plural}(?![a-z])/, to.pluralize.underscore ],
    [ /(?<![a-zA-Z0-9])#{dasherized_plural}(?![a-z])/, to.pluralize.underscore.dasherize ]
  ]
end

patterns = []
RENAME_RULES.each do |from, to|
  patterns.concat(build_patterns(from, to))
end

Find.find(".") do |path|
  next if File.directory?(path)
  next unless EXTENSIONS.include?(File.extname(path))
  next if EXCLUDED_DIRS.any? { |dir| path.start_with?("./#{dir}/") }

  content = File.read(path)
  original_content = content.dup

  patterns.each do |regex, replacement|
    content.gsub!(regex, replacement)
  end

  if content != original_content
    puts "Renaming in: #{path}"
    File.write(path, content)
  end
end
