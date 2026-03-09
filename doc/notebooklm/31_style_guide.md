# Gist Style Guide — RoleplayCore

Standards for producing polished, professional GitHub Gist documents.

---

## Document Structure

### Required Sections (in order)

```
# Title
## Subtitle
**Metadata line** (audience, date, project)

> **TL;DR** — one-paragraph summary

---

## Navigation (always-visible TOC table)

---

## Executive Summary (always open — the hook)

<details> Part 1 — collapsible with summary line </details>
<details> Part 2 — collapsible with summary line </details>
...
<details> Appendix A </details>

---
*Footer: date, repo, tool repos*
```

### Metadata Line

Always include audience, date, and project scope on line 3–4:

```markdown
**Prepared for [Audience]**
**[Date] | [Project] — [Client/Build]**
```

### TL;DR Block

One blockquote paragraph immediately before the Executive Summary. Hit every headline number. Example:

```markdown
> **TL;DR** — [action] [number], [action] [number], ... All tooling is [status].
```

---

## Navigation / Table of Contents

Use an **always-visible** `## Navigation` heading with a table. Don't hide the TOC behind a `<details>` tag — it's too easy to miss. The TOC is the reader's map; it should be immediately visible.

```markdown
## Navigation

| # | Section | Headline |
|---|---------|----------|
| — | [Executive Summary](#executive-summary) | Full numbers table |
| 1 | [Section Name](#anchor) | Key metric |
| 2 | [...](#...) | ... |
| A | [Appendix Name](#anchor) | ... |
```

The three-column format (number, linked title, headline metric) gives readers both navigation and a reason to click.

## Collapsible Content Sections

Wrap every major section (Part 1, Part 2, etc.) in `<details>` so readers can expand only what they need. Use `<strong>` for the title and `<em>` for a one-line summary:

```html
<details>
<summary><strong>Part 1: Section Title</strong> &mdash; <em>Key metric or description</em></summary>

Section content here (regular Markdown).

### 1.1 Subsection
...

</details>
```

**Rules:**
- `<summary>` must be a single line — no `<h2>` (GitHub strips heading tags inside summary)
- Leave a blank line after `</summary>` for Markdown to render inside the block
- Leave a blank line before `</details>`
- Nest `<details>` for sub-catalogs (e.g., Part 16 subsections inside Part 16's details)

**What stays open (no `<details>`):**
- Title + metadata
- TL;DR blockquote
- Navigation table
- Executive Summary (the hook — readers need to see this immediately)

### Anchor Rules (GitHub)

GitHub auto-generates anchors from headings:
- Lowercase everything
- Replace spaces with `-`
- Strip most punctuation except `-`
- `&` becomes `--` (double hyphen)
- Backticks (`` ` ``) are stripped
- Parentheses are stripped
- Consecutive `-` are **not** collapsed (unlike some parsers)

Examples:
| Heading | Anchor |
|---------|--------|
| `## Part 3: NPC Audits & Corrections` | `#part-3-npc-audits--corrections` |
| `` ### 14.3 MySQL `tmp_table_size` Default Trap `` | `#143-mysql-tmp_table_size-default-trap` |
| `### 7.1 Server Startup: 3m24s -> 60s -> 17s` | `#71-server-startup-3m24s---60s---17s` |

**Tip**: Don't use `→` in headings — it creates unpredictable anchors. Keep `->` in headings, use `→` in body text only.

---

## Typography

### Em-Dash `—` (U+2014)

Use `—` for parenthetical asides and attribution. Never use `--` or `â€"` (mojibake).

```markdown
97.8% of rows were redundant — identical to client DBC baseline.
```

**Encoding trap**: If you copy-paste from Windows apps or PDFs, em-dashes can double-encode as `â€"` (UTF-8 → CP1252 → UTF-8). Always verify with a hex check or `grep 'â€' file.md`.

### Arrows `→` (U+2192)

Use `→` for transformations, migrations, and flow in body text and tables:

```markdown
| Server startup | 3m24s → 17s (92% reduction) |
```

**Do not** use `→` in headings (breaks anchor links). Use `->` in headings only.

### En-Dash `–` (U+2013)

Use for ranges: `Feb 26 – Mar 5`, `Sessions 13–30`. Not required in tables where `→` reads better.

### Quotes and Apostrophes

Use straight quotes (`'` and `"`) in Markdown. Curly quotes (`'`, `"`, `"`) cause mojibake risk and add no value in technical documents.

---

## Formatting Patterns

### Tables

- Always include a header separator: `|---|---|`
- Bold category labels in the first column for grouped tables
- Right-align numbers if the renderer supports it (GitHub does not, so don't bother)
- Empty first-column cells for continuation rows: `| | Hotfix rows | 103K |`

### Collapsible Sub-Catalogs

For inventory/catalog subsections nested inside a collapsible Part, use a second level of `<details>`:

```html
<details>
<summary><strong>16.1 Python Data Pipeline Tools</strong> (14 tools)</summary>

| Tool | Purpose |
|------|---------|
| ...  | ...     |

</details>
```

This keeps detailed inventories accessible without overwhelming the reader when they expand the parent section.

### Cross-References

Always link when referencing another section:

```markdown
The redundancy audit ([Part 13](#part-13-hotfix-redundancy-audit-complete)) reduced...
```

Never write "see Part 13" as plain text when you can link it.

### Blockquote Notes

Use `>` blockquotes for contextual notes, caveats, and post-hoc updates:

```markdown
> **Note**: Most hotfix tables were nearly emptied by the redundancy audit — their data matched the client's DBC baseline.
```

Use `> **Post-audit update**:` for information that was added after the section was originally written.

---

## Content Guidelines

### Numbers

- Use commas for thousands: `103,153` not `103153`
- Use `~` for approximations: `~244K`
- Use `K` / `M` for large round numbers in summaries: `10.8M rows`
- Use exact numbers in detail tables: `103,153 inserts`
- Always specify units: `637 MB`, `17s`, `72 lines`

### Code References

- Inline code for: file names, table names, column names, config keys, function names
- Code blocks for: SQL, Python, shell commands (only when showing reproducible steps)
- Never use code formatting for emphasis — use **bold** instead

### Before/After Sections

The most impactful structure for demonstrating value. Use parallel bullet lists:

```markdown
### Before
- [problem] — [consequence]
- [problem] — [consequence]

### After
- [fix] — [result with number]
- [fix] — [result with number]
```

Every "After" bullet should have a measurable outcome.

---

## Pre-Publish Checklist

1. **Encoding**: `grep 'â€' file.md` — must return zero matches
2. **Tag balance**: `<details>` count == `</details>` count
3. **Collapsibles**: Verify every `<details>` block expands/collapses correctly after publishing
4. **Anchors**: Click every Navigation table link (GitHub's preview can differ from final render)
5. **Summaries**: Each `<summary>` has the correct Part title and metric — watch for substring bugs (Part 1 matching Part 10)
6. **Cross-refs**: Search for "see Part", "see Section", "Part N)" — all should be `[linked](#anchor)`
7. **Typography**: No `--` where `—` belongs, no `->` in body text (use `→`), no `→` in headings
8. **Numbers**: Consistent formatting (commas, K/M abbreviations, units)
9. **Tables**: All rows have correct pipe count, header separators present
10. **Always visible**: TL;DR, Navigation, and Executive Summary must NOT be inside `<details>`
11. **Footer**: Date, repo link, tool repos — must be outside the last `</details>`

---

## Quick Reference: Unicode Characters

| Character | Code Point | Usage | Type on Windows |
|-----------|-----------|-------|-----------------|
| `—` | U+2014 | Em-dash (asides) | Alt+0151 |
| `–` | U+2013 | En-dash (ranges) | Alt+0150 |
| `→` | U+2192 | Arrow (transforms) | Copy-paste |
| `←` | U+2190 | Arrow (reverse) | Copy-paste |
| `↔` | U+2194 | Arrow (bidirectional) | Copy-paste |
| `~` | U+007E | Approximation | Keyboard |

---

*RoleplayCore — VoxCore84/RoleplayCore*
