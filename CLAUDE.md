# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development
```bash
# This site requires Ruby 3.3.6
# Switch to Ruby 3.3.6 if using RVM
rvm use 3.3.6

# Install dependencies
bundle install

# Start development server
bundle exec middleman server

# Build the site
bundle exec middleman build
```

### Deployment
The site appears to be configured for static deployment (build output goes to `/build` directory).

## Architecture

This is a simple personal bio site built with Middleman, a Ruby-based static site generator.

### Project Structure
- `source/` - All source content and templates
  - `index.html.erb` - Main page content with frontmatter (title, description, keywords)
  - `layouts/layout.erb` - HTML layout template with meta tags and OpenGraph properties
  - `stylesheets/site.css.scss` - Sass stylesheet with custom styling
  - `javascripts/site.js` - JavaScript (minimal)
  - `images/` - Static images
- `config.rb` - Middleman configuration with autoprefixer
- `Gemfile` - Ruby dependencies (Middleman 4.4.2, autoprefixer, haml)

### Key Features
- ERB templating with frontmatter for page metadata
- SCSS preprocessing for styles
- Autoprefixer for CSS vendor prefixes
- OpenGraph meta tags for social sharing
- Single-page personal bio with external links

### Content Management
The main bio content is in `source/index.html.erb` with a "last updated" date that should be manually updated when content changes.

## Code Editing Guidelines

When making edits to HTML, CSS, or JavaScript files, always add a comment indicating that the change was made by Claude Code. Use appropriate comment syntax for each file type:

- HTML/ERB: `<!-- Added by Claude Code -->`
- CSS/SCSS: `/* Added by Claude Code */`
- JavaScript: `// Added by Claude Code`
