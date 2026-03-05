# Gist Style Guide — RoleplayCore

Standards for producing polished, professional GitHub Gist documents.

---

## Document Structure

### Required Sections (in order)

```
# Title
## Subtitle
**Metadata line** (audience, date, project)

---

<details> Table of Contents (collapsible) </details>

> **TL;DR** — one-paragraph summary

## Executive Summary (numbers table)

## Parts 1–N (main content)

## Appendices (reference data)

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

## Table of Contents

Use a **collapsible `<details>` tag** with a summary table. This avoids consuming 70+ lines of vertical space while remaining fully navigable.

```html
<details>
<summary><strong>Table of Contents</strong> (click to expand)</summary>

| Part | Title | Key Metric |
|------|-------|-----------|
| 1 | [Section Name](#anchor) | Headline number |
| 2 | [...](#...) | ... |
| A | [Appendix Name](#anchor) | ... |

</details>
```

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

### Collapsible Sections

Use `<details>` for:
- Tables of contents
- Long catalog/inventory tables (5+ rows of repetitive structure)
- Supplementary detail that most readers will skip

```html
<details>
<summary><strong>Section Title</strong> (N items)</summary>

| Col 1 | Col 2 |
|-------|-------|
| ...   | ...   |

</details>
```

**Important**: Leave a blank line after `<summary>` and before `</details>` for proper Markdown rendering inside the tag.

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
2. **Anchors**: Click every TOC link after publishing (GitHub's preview can differ from final render)
3. **Collapsibles**: Verify `<details>` blocks expand/collapse correctly
4. **Cross-refs**: Search for "see Part", "see Section", "Part N)" — all should be linked
5. **Typography**: No `--` where `—` belongs, no `->` in body text (use `→`)
6. **Numbers**: Consistent formatting (commas, K/M abbreviations, units)
7. **Tables**: All rows have correct pipe count, header separators present
8. **Footer**: Date, repo link, tool repos

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
