#!/usr/bin/env ruby
# Added by Claude Code
# This script previews the email template with data from a newsletter markdown file
# It compiles SCSS, converts markdown to HTML, and inlines CSS using Premailer

require 'erb'
require 'yaml'
require 'sassc'
require 'redcarpet'
require 'premailer'

# If no argument provided, show interactive menu
if ARGV.empty?
  puts "\nSelect a newsletter to preview:\n\n"

  # Find all markdown files in the-becoming folder
  newsletter_files = Dir.glob('source/the-becoming/*.html.md').sort

  if newsletter_files.empty?
    puts "Error: No newsletter files found in source/the-becoming/"
    exit 1
  end

  # Display numbered list of newsletters
  newsletter_files.each_with_index do |file, index|
    # Extract just the filename without path and extension for display
    display_name = File.basename(file, '.html.md')
    puts "  #{index + 1}. #{display_name}"
  end

  print "\nEnter number (or 'q' to quit): "
  choice = gets.chomp

  # Handle quit
  if choice.downcase == 'q'
    puts "Cancelled."
    exit 0
  end

  # Validate and get the selected file
  choice_num = choice.to_i
  if choice_num < 1 || choice_num > newsletter_files.length
    puts "Error: Invalid choice"
    exit 1
  end

  markdown_file = newsletter_files[choice_num - 1]
  puts "\n"
else
  # Use the provided argument
  markdown_file = ARGV[0]
end

# Check if the file exists
unless File.exist?(markdown_file)
  puts "Error: File not found: #{markdown_file}"
  exit 1
end

# Read the markdown file
content = File.read(markdown_file)

# Parse frontmatter from the markdown file
# Frontmatter is between --- markers at the top of the file
if content =~ /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m
  frontmatter = YAML.load($1)
  markdown_content = content[($1.size + $2.size)..-1]
else
  puts "Error: No frontmatter found in #{markdown_file}"
  exit 1
end

# Extract the data from frontmatter
title = frontmatter['title']
issue = frontmatter['issue']
date = frontmatter['date']

puts "Generating preview for:"
puts "  Title: #{title}"
puts "  Issue: #{issue}" if issue
puts "  Date: #{date}" if date

# ==========================================
# STEP 1: Convert markdown to HTML
# ==========================================
puts "\nConverting markdown to HTML..."

# Configure Redcarpet markdown renderer (same as Middleman uses)
renderer = Redcarpet::Render::HTML.new(
  filter_html: false,
  no_images: false,
  no_links: false,
  hard_wrap: false
)

markdown_processor = Redcarpet::Markdown.new(renderer,
  autolink: true,
  tables: true,
  fenced_code_blocks: true,
  strikethrough: true,
  superscript: true
)

# Convert markdown content to HTML
content = markdown_processor.render(markdown_content)

# Generate web URL for this newsletter
# e.g., "becoming-as-praxis.html.md" -> "https://andreamignolo.com/the-becoming/becoming-as-praxis/"
filename = File.basename(markdown_file, '.html.md')
web_url = "https://andreamignolo.com/the-becoming/#{filename}/"

# ==========================================
# STEP 2: Compile SCSS to CSS
# ==========================================
puts "Compiling SCSS to CSS..."

scss_path = 'source/stylesheets/email.scss'
scss_content = File.read(scss_path)

# Compile SCSS to CSS
css_engine = SassC::Engine.new(scss_content, {
  syntax: :scss,
  style: :expanded,
  load_paths: ['source/stylesheets']
})
styles = css_engine.render

# ==========================================
# STEP 3: Generate HTML from template
# ==========================================
puts "Generating HTML from template..."

# Read the email template
template_path = 'source/layouts/the-becoming-email.erb'
template_content = File.read(template_path)

# Create an ERB template object
template = ERB.new(template_content)

# Generate the HTML by evaluating the template with our variables
# This will inject: title, issue, date, content, web_url, and styles
html_with_styles = template.result(binding)

# ==========================================
# STEP 4: Inline CSS with Premailer
# ==========================================
puts "Inlining CSS with Premailer..."

# Use Premailer to inline all CSS styles
premailer = Premailer.new(html_with_styles,
  with_html_string: true,
  warn_level: Premailer::Warnings::SAFE
)

# Get the final HTML with inlined styles
html_output = premailer.to_inline_css

# Check for any CSS warnings (optional, helpful for debugging)
if premailer.warnings.any?
  puts "\nPremailer warnings:"
  premailer.warnings.each { |w| puts "  - #{w}" }
end

# ==========================================
# STEP 5: Write output file
# ==========================================

# Write the output to a preview file in the source/ folder so Middleman can serve it
output_file = 'source/email_preview.html'
File.write(output_file, html_output)

puts "\n✓ Preview generated: #{output_file}"
puts "View it at: http://localhost:4567/email_preview.html"
