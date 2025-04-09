#!/usr/bin/env ruby

require "fileutils"
require "active_support/core_ext/string" # for camelize

# Configuration
EXCLUDED_DIRS = [ "db", ".git", "script/renaming" ].freeze

RENAMES = {
  "bubble" => "card",
  "poppable" => "closeable",
  "popped" => "closed",
  "pop" => "closure",
  "bucket" => "collection"
}.freeze

FILE_EXTENSIONS = %w[rb yml html css js jpg jpeg png gif svg erb].freeze

def excluded_path?(path)
  EXCLUDED_DIRS.any? { |excluded| path.split(File::SEPARATOR).include?(excluded) }
end

def rename_path(path)
  new_path = path.dup

  RENAMES.each do |from, to|
    # Replace snake_case, kebab-case, plain, and CamelCase versions
    patterns = [
      [ /(?<=\A|[^a-zA-Z0-9])#{from}(?=[^a-zA-Z0-9]|\z)/i, to ],
      [ from.camelize, to.camelize ],
      [ from.camelize(:lower), to.camelize(:lower) ],
      [ from.underscore.dasherize, to.underscore.dasherize ],
      [ from.underscore, to.underscore ]
    ]

    patterns.each do |pattern, replacement|
      new_path.gsub!(pattern, replacement)
    end
  end

  new_path
end

# Rename Directories First
dirs = Dir.glob("**/*/").reject { |path| excluded_path?(path) }.sort_by { |dir| -dir.count("/") }

puts "Renaming directories..."
dirs.each do |dir|
  clean_dir = dir.chomp("/")
  new_dir = rename_path(clean_dir)

  next if clean_dir == new_dir
  next if File.exist?(new_dir)

  puts "Renaming dir: #{clean_dir} => #{new_dir}"
  FileUtils.mkdir_p(File.dirname(new_dir))
  FileUtils.mv(clean_dir, new_dir)
end

# Rename Files
files = Dir.glob("**/*.{#{FILE_EXTENSIONS.join(",")}}").reject { |path| excluded_path?(path) }

puts "Renaming files..."
files.each do |file|
  new_file = rename_path(file)

  next if file == new_file
  next if File.exist?(new_file)

  puts "Renaming file: #{file} => #{new_file}"
  FileUtils.mkdir_p(File.dirname(new_file))
  FileUtils.mv(file, new_file)
end

puts "Renaming complete!"
