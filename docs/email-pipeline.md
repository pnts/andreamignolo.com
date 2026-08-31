# Email Newsletter Pipeline

A self-contained Ruby pipeline for writing newsletters in Markdown, previewing them locally, and publishing to Buttondown as drafts. Built for use with Middleman but the script is independent of it.

---

## Overview

The pipeline takes a Markdown file with YAML frontmatter, converts it to styled HTML, inlines all CSS, and either writes a local preview or posts it to the Buttondown API as a draft.

```
Markdown + SCSS
      ↓
  Redcarpet (Markdown → HTML)
      ↓
  Custom attribute processing ({: .class} syntax)
      ↓
  Image URL rewriting (relative ↔ absolute)
      ↓
  SassC (SCSS → CSS)
      ↓
  ERB template rendering
      ↓
  Premailer (inline CSS)
      ↓
  Local preview file  OR  Buttondown draft via API
```

---

## File Structure

```
project/
├── scripts/
│   └── preview_email.rb              # Main pipeline script
├── source/
│   ├── layouts/
│   │   └── the-becoming-email.erb    # HTML email template
│   ├── stylesheets/
│   │   └── email.scss                # Email styles (compiled + inlined)
│   ├── the-becoming/
│   │   └── *.html.md                 # Newsletter content files
│   └── email_preview.html            # Generated preview output (gitignored)
├── .env                              # BUTTONDOWN_API_KEY (never commit)
└── Gemfile
```

---

## Dependencies

Add to `Gemfile`:

```ruby
gem 'sassc'        # Compiles SCSS to CSS
gem 'redcarpet'    # Markdown to HTML
gem 'premailer'    # Inlines CSS into HTML (required for email clients)
gem 'dotenv'       # Loads .env file for API keys
```

The script also uses Ruby stdlib: `erb`, `yaml`, `net/http`, `json`, `uri`.

---

## Newsletter Content Format

Files live in `source/the-becoming/` with the `.html.md` extension. The filename becomes the URL slug.

```markdown
---
title: The Newsletter Title
date: February 11, 2024
issue: 2
description: optional description
published: true
---

Regular markdown content here. Paragraphs, **bold**, *italic*, links, etc.

![Alt text](the-becoming/image-name.jpg)
Caption text here.
{: .figcaption}

A centered section marker.
{: .center}

Text with a footnote.[^1]

[^1]: The footnote text.
```

### Frontmatter fields

| Field | Required | Purpose |
|-------|----------|---------|
| `title` | Yes | Email subject line + displayed in header |
| `date` | No | Displayed in header (freeform string) |
| `issue` | No | Issue number displayed in header |
| `description` | No | Used by Middleman for web page meta |
| `published` | No | Used by Middleman for web page listing |

---

## Custom Markdown Syntax

Redcarpet doesn't support Kramdown-style attribute syntax, so the script post-processes the rendered HTML with regex substitutions.

### `{: .figcaption}` — image captions

```markdown
![Alt text](path/to/image.jpg)
Caption text here.
{: .figcaption}
```

Rendered as:
```html
<img src="..." alt="Alt text">
<p class="figcaption">Caption text here.</p>
```

### `{: .center}` — centered text

```markdown
i.
{: .center}
```

Rendered as:
```html
<p class="center">i.</p>
```

### Footnotes

Standard Redcarpet footnote syntax is enabled:

```markdown
Something interesting.[^1]

[^1]: The interesting thing explained.
```

Redcarpet renders these as `<div class="footnotes">` with `<sup>` tags for the inline references.

---

## HTML Email Template

`source/layouts/the-becoming-email.erb`

Table-based layout — required for email client compatibility since flexbox/grid don't work reliably across email clients. The template receives these ERB variables from `binding`:

| Variable | Source |
|----------|--------|
| `title` | Frontmatter |
| `issue` | Frontmatter |
| `date` | Frontmatter |
| `content` | Rendered + processed Markdown |
| `web_url` | Derived from filename |
| `styles` | Compiled CSS string |

The `styles` variable is injected into a `<style>` block in `<head>`, then Premailer inlines everything into `style=""` attributes on each element. The `<style>` block is left in place (some clients need it) but the inline styles take precedence everywhere else.

### Template structure

```
<html>
  <head><style>CSS from email.scss</style></head>
  <body>
    <table.email-wrapper>       ← full-width background
      <table.email-container>   ← max 700px, centered
        header-section          ← issue #, date, web link, title
        content-section         ← rendered markdown
        footer-section          ← tagline, links, unsubscribe
      </table>
    </table>
  </body>
</html>
```

### Buttondown unsubscribe

The footer uses Buttondown's template variable for the unsubscribe link:

```html
<a href="{{unsubscribe_url}}">Unsubscribe here</a>
```

Buttondown replaces `{{unsubscribe_url}}` at send time. This is the only Buttondown-specific markup in the template.

---

## Email Styles

`source/stylesheets/email.scss`

Standard SCSS compiled by SassC. Key design decisions:

- **White background** — works inside Buttondown's own wrapper
- **700px max-width container** — slightly wider than the classic 600px
- **System font stack** — no web fonts (unreliable in email clients)
- **`$accent-color`** — used for link underline color (`text-decoration-color`)
- **Footnotes** — `.footnotes` class gets smaller text and reduced opacity
- **`sup`** — `line-height: 0` prevents superscripts from blowing out line spacing

All styles are processed by Premailer and inlined before sending.

---

## Image Paths

Images are stored in `source/images/` and referenced in Markdown as relative paths:

```markdown
![Alt](the-becoming/image-name.jpg)
```

The script rewrites `src` attributes depending on mode:

- **Local preview** → `/images/the-becoming/image-name.jpg` (works with Middleman dev server at `localhost:4567`)
- **Buttondown send** → `https://andreamignolo.com/images/the-becoming/image-name.jpg` (absolute URL required for email delivery)

**Important:** Images must be deployed to the live site before sending, because email clients fetch them at open time from the absolute URL.

---

## Running the Script

### Interactive mode (shows a menu)

```bash
ruby scripts/preview_email.rb
```

### Preview a specific file

```bash
ruby scripts/preview_email.rb source/the-becoming/newsletter-name.html.md
```

Preview is written to `source/email_preview.html`. If the Middleman dev server is running, view it at `http://localhost:4567/email_preview.html`.

### Send to Buttondown as draft

```bash
ruby scripts/preview_email.rb --send
# or
ruby scripts/preview_email.rb source/the-becoming/newsletter-name.html.md --send
```

The `--send` flag can appear anywhere in the argument list. The script prompts for confirmation before posting. It creates a **draft** in Buttondown (status: `"draft"`) — it does not send to subscribers.

---

## Buttondown API Integration

Endpoint: `POST https://api.buttondown.email/v1/emails`

Auth: `Authorization: Token YOUR_API_KEY`

Payload:
```json
{
  "subject": "The Newsletter Title",
  "body": "<html>...full inlined HTML...</html>",
  "status": "draft",
  "template": null
}
```

**`status: "draft"` is critical.** If you omit this field or use `"published"`, Buttondown will immediately send the email to all subscribers. There is no undo. Always set `status: "draft"` when creating via the API — the draft then lives in Buttondown's dashboard where you can review it and send manually when ready.

`template: null` bypasses Buttondown's default template wrapper so the custom HTML is used as-is.

### Setup

Create `.env` in the project root (never commit this):

```
BUTTONDOWN_API_KEY=your-api-key-here
```

Get the API key from Buttondown → Settings → API.

---

## Pipeline Steps in Detail

### Step 1 — Parse frontmatter

Splits the file at `---` markers using a regex, parses the YAML header with `YAML.load`, and keeps the remaining content as the Markdown body.

### Step 2 — Markdown to HTML

Redcarpet is configured with:
- `footnotes: true` — enables `[^1]` syntax
- `autolink: true`, `tables: true`, `fenced_code_blocks: true`, `strikethrough: true`, `superscript: true`
- `hard_wrap: false` — single newlines don't become `<br>` tags

### Step 3 — Post-process HTML

Four regex passes over the rendered HTML:

1. `{: .figcaption}` on image+text paragraphs → split into `<img>` + `<p class="figcaption">`
2. `{: .figcaption}` on text-only paragraphs → `<p class="figcaption">`
3. `{: .center}` mid-paragraph → split into centered + continuation paragraphs
4. `{: .center}` at end of paragraph → `<p class="center">`
5. Clean up stray `<br>` tags at paragraph starts

### Step 4 — Rewrite image URLs

Single regex over all `src=` attributes. Strips leading slash, ensures `images/` prefix, then applies relative or absolute base depending on `--send` flag.

### Step 5 — Compile SCSS

SassC compiles `email.scss` with `load_paths: ['source/stylesheets']` so `@import` works for partials.

### Step 6 — Render ERB template

`ERB.new(template).result(binding)` passes all local variables into the template. The compiled CSS string is injected directly into the `<style>` block.

### Step 7 — Inline CSS with Premailer

```ruby
premailer = Premailer.new(html, with_html_string: true, warn_level: Premailer::Warnings::SAFE)
html_output = premailer.to_inline_css
```

Premailer parses the `<style>` block, computes specificity, and writes `style=""` attributes on every matching element. The original `<style>` block is kept in the output (Gmail strips it, but many other clients use it as a fallback).

### Step 8 — Output

- **Preview:** write to `source/email_preview.html`
- **Send:** POST to Buttondown API, print draft ID on success

---

## Adapting for Another Project

1. Copy `scripts/preview_email.rb`, `source/layouts/the-becoming-email.erb`, `source/stylesheets/email.scss`
2. Add gems to `Gemfile`: `sassc`, `redcarpet`, `premailer`, `dotenv`
3. Update paths in the script:
   - `Dir.glob(...)` — where your newsletter `.md` files live
   - `scss_path` — path to your email stylesheet
   - `template_path` — path to your email template
   - `output_file` — where to write local previews
   - `base_url` — your production domain for image URLs
   - `web_url` derivation logic — your URL structure
4. Update the ERB template footer with your newsletter's copy and real unsubscribe URL (or keep `{{unsubscribe_url}}` if using Buttondown)
5. Create `.env` with `BUTTONDOWN_API_KEY`
6. Add `source/email_preview.html` and `.env` to `.gitignore`
