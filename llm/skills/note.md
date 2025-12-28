# Skill Ideas

Ideas for future Agent Skills to add.

## blog-writing (for agude.github.io)

**Purpose:** Writing and publishing blog posts

Key knowledge needed:
- Jekyll-based site with Docker workflow (`make serve`, `make build`)
- Post location: `_posts/YYYY-MM-DD-slug_with_underscores.md`
- Frontmatter: title, description, image, image_alt, categories
- Category slugs: `data-science`, `machine-learning`, `generative-ai`, etc.
- Asset paths: `/files/subdirectory/image.jpg`
- Cross-references: `{% post_url YYYY-MM-DD-slug %}`
- Drafts workflow: `_drafts/` → `_posts/`

## book-review (for agude.github.io)

**Purpose:** Writing book reviews (different format than posts)

Key knowledge needed:
- Location: `_books/title_in_snake_case.md`
- Different frontmatter: `book_authors`, `rating` (1-5), `series`, `book_number`, `awards`
- Book covers: `/books/covers/`
- Special tags: `{% book_link %}`, `{% author_link %}`, `{% series_link %}`

## jekyll-refactor (for agude.github.io)

**Purpose:** Understanding the plugin architecture for code refactoring

Key knowledge needed:
- Domain-Driven Design in `_plugins/src/`: content/, infrastructure/, ui/, seo/
- Tags are thin wrappers; Utils orchestrate; Finders fetch; Renderers output
- Test matching: every plugin class needs a `_tests/` counterpart
- Link cache system for O(1) lookups
- Error handling with `PluginLoggerUtils.log_liquid_failure`

---

**Note:** The blog repo already has a detailed `CLAUDE.md`. These skills could
either duplicate that info (self-contained) or reference/extend it. TBD based
on how skills interact with project-level CLAUDE.md files.
