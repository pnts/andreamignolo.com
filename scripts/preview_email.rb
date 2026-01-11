#!/usr/bin/env ruby
# Added by Claude Code
# This script previews the email template with data from a newsletter markdown file
# It compiles SCSS, converts markdown to HTML, and inlines CSS using Premailer

require 'erb'
require 'yaml'
require 'sassc'
require 'redcarpet'
require 'premailer'
require 'net/http'
require 'json'
require 'uri'
require 'dotenv/load'  # Load environment variables from .env file

# Parse command line arguments
# Check if --send flag is present
send_to_buttondown = ARGV.include?('--send')
# Remove the --send flag from ARGV so it doesn't interfere with file selection
ARGV.delete('--send')

# If no argument provided (after removing flags), show interactive menu
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

# Process figcaptions - convert {: .figcaption} syntax to proper HTML
# Find paragraphs ending with {: .figcaption} and add the class to the <p> tag
content = content.gsub(/<p>(.*?)\n?\{:\s*\.figcaption\s*\}<\/p>/m) do |match|
  caption_text = $1.strip
  "<p class=\"figcaption\">#{caption_text}</p>"
end

# Process image URLs to make them absolute for email
# Converts relative paths like "the-becoming/image.jpg" to "https://andreamignolo.com/images/the-becoming/image.jpg"
base_url = 'https://andreamignolo.com'
content = content.gsub(/src=["'](?!http)([^"']+)["']/) do |match|
  relative_path = $1
  # Remove leading slash if present
  relative_path = relative_path.sub(/^\//, '')
  # Add /images/ prefix if not already there
  relative_path = "images/#{relative_path}" unless relative_path.start_with?('images/')
  "src=\"#{base_url}/#{relative_path}\""
end

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
# STEP 5: Output - Preview or Send
# ==========================================

if send_to_buttondown
  # Show confirmation prompt before sending
  puts "\n" + "=" * 60
  puts "CONFIRMATION: Send to Buttondown"
  puts "=" * 60
  puts "Newsletter: #{title}"
  puts "Issue: ##{issue}" if issue
  puts "Date: #{date}" if date
  puts "This will create a DRAFT (not send to subscribers)"
  puts "=" * 60
  print "\nType 'yes' to continue, anything else to cancel: "

  confirmation = gets.chomp

  unless confirmation.downcase == 'yes'
    puts "\nCancelled. No email was sent to Buttondown."
    exit 0
  end

  puts "\nSending to Buttondown..."

  # Get API key from environment variable
  api_key = ENV['BUTTONDOWN_API_KEY']

  unless api_key
    puts "\n✗ Error: BUTTONDOWN_API_KEY not found"
    puts "Add your API key to the .env file in the project root:"
    puts "  BUTTONDOWN_API_KEY=your-api-key"
    puts "\nGet your API key from: https://buttondown.email/settings"
    exit 1
  end

  # Buttondown API endpoint
  uri = URI('https://api.buttondown.email/v1/emails')

  # Create HTTP client
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  # Create the request
  request = Net::HTTP::Post.new(uri.path)
  request['Authorization'] = "Token #{api_key}"
  request['Content-Type'] = 'application/json'

  # Build the JSON payload
  # status: "draft" keeps the email as a draft (won't send to subscribers)
  # template: null attempts to bypass Buttondown's template wrapper for custom HTML
  payload = {
    subject: title,
    body: html_output,
    status: 'draft',
    template: nil
  }

  request.body = payload.to_json

  # Debug output - show what we're sending
  puts "\nDEBUG: Payload being sent:"
  puts "  Subject: #{payload[:subject]}"
  puts "  Body length: #{payload[:body].length} characters"
  puts "  Status: #{payload[:status]}"
  puts "  Template: #{payload[:template].inspect}"

  # Send the request
  begin
    response = http.request(request)

    # Check if successful (2xx status code)
    if response.code.to_i.between?(200, 299)
      puts "\n" + "=" * 60
      puts "✓ SUCCESS: Draft created in Buttondown!"
      puts "=" * 60
      puts "Subject: #{title}"

      # Show response data if available
      if response.body && !response.body.empty?
        response_data = JSON.parse(response.body)
        puts "Draft ID: #{response_data['id']}" if response_data['id']
        puts "Status: #{response_data['status']}" if response_data['status']
      end

      puts "\nNext steps:"
      puts "1. Check your draft at: https://buttondown.email/emails"
      puts "2. Review the email content and styling"
      puts "3. Use Buttondown to send when ready"
      puts "=" * 60
    else
      puts "\n✗ Error sending to Buttondown:"
      puts "Status: #{response.code}"
      puts "Response: #{response.body}"
      exit 1
    end
  rescue => e
    puts "\n✗ Exception occurred: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end

else
  # Write preview file
  output_file = 'source/email_preview.html'
  File.write(output_file, html_output)

  puts "\n✓ Preview generated: #{output_file}"
  puts "View it at: http://localhost:4567/email_preview.html"
  puts "\nTo send to Buttondown instead, run with --send flag:"
  puts "  ruby scripts/preview_email.rb --send"
end
