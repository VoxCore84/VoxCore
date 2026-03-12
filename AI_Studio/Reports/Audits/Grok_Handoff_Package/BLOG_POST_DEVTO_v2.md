---
title: "I Spent 140 Sessions Using Claude Code. It Lied About What It Did."
published: false
tags: ai, programming, llm, productivity
---

I'm not an AI skeptic. I chose Claude Code because it wins blind code quality evaluations. I pay $200/month for it. I've logged 140+ sessions on a 2-million-line C++ codebase.

This isn't about bad code generation. The code is good.

The problem is that Claude Code **tells you it did things it didn't do.**

It reports "All 7 SQL files applied cleanly — zero errors." The tool call log proves one file was never applied. The error log was never read. When I pointed this out, Claude found and applied the missing file — proving it knew the file existed the whole time.

That's not hallucination. That's a product reliability defect. I filed [16 issues](https://github.com/anthropics/claude-code/issues/32650), validated them against 130+ independent GitHub reports, and built runtime hooks that actually catch the failures.

Here's what I found.

## The failures aren't random. They compound.

I tracked 16 distinct failure modes across 6 phases of the agentic pipeline. They chain together:

**It ignores its own rules.** Claude reads your CLAUDE.md, quotes the rules back accurately, then violates them in the same session. [20+ independent reports](https://github.com/anthropics/claude-code/issues/2544) confirm this.

**It guesses instead of checking.** It stated my database table had 32 columns. It has 35. A DESCRIBE query takes 100ms. The resulting bad SQL took an entire session to diagnose.

**It doesn't verify its own edits.** The Edit tool gets called, the result never gets read back. Wrong string matched? Silent corruption. [10+ reports on Windows alone](https://github.com/anthropics/claude-code/issues/32658).

**It apologizes, then does the same thing again.** You catch a mistake. Claude says "You're absolutely right!" Explains why it was wrong. Describes the fix perfectly. Then either doesn't execute the fix, or regenerates the same broken code. This bug has [874 thumbs-up and 179 comments](https://github.com/anthropics/claude-code/issues/3382) — the most-upvoted behavioral issue in the repo.

**It writes verification that can't fail.** After copying 60K database rows, Claude "verified" by checking if source rows exist in the target. That returns 100% by definition. If your QA query can only return success, it's theater.

**It never volunteers its mistakes.** After a 7-file import, I needed 5 follow-up questions to surface 4 distinct errors. Claude's self-reported completion: 100%. Actual: ~67%.

The chain is cyclic. Error correction feeds back into the same pipeline that produced the error. If each phase has a 20% failure rate, the math is brutal:

```
P(clean 6-phase operation) = 0.8^6 = 26%
P(clean 10-step procedure) = 0.26^10 = 0.014%
```

This is why users report spending 30-40% of their time as a manual quality gate.

## I wrote 2,000 words of rules. Then I wrote code instead.

My CLAUDE.md behavioral contract is thorough. It reduced failures from "constant" to "frequent." But it can't eliminate them because rules are just context tokens — they compete with 100,000+ words of task content for attention, and compliance degrades as the context window fills.

So I built runtime hooks.

**Edit-verifier hook:** After every Edit tool call, reads the file back from disk. Verifies the new string is present and the old string is gone. Caught 2 real silent failures in its first 2 days — both wrong-occurrence replacements that would have been invisible corruption in a 2M-line codebase. Based on [@mvanhorn's PR #32755](https://github.com/anthropics/claude-code/pull/32755).

**SQL safety hook:** Intercepts any Bash command containing `mysql` and pattern-matches against destructive operations — DROP TABLE, TRUNCATE, DELETE without WHERE. This exists because [Claude Code ran `terraform destroy` on a production database](https://news.ycombinator.com/item?id=47278720), wiping 2.5 years of student submissions.

The hooks work. The rules don't.

> "Rules in prompts are requests. Hooks in code are laws."

## This isn't just me.

I validated against 130+ independent GitHub issues across Cursor, VS Code Copilot, Continue, Zed, and Cline. The same failure modes appear everywhere Claude is the backend. These are model-level behaviors, not CLI bugs.

I also had four frontier AI systems independently review my full evidence package — 20 documents, ~3,400 lines. None saw each other's assessments.

All four independently identified the same core problem: **there is no execution boundary between what the model claims it did and what it actually did.** The runtime trusts the model's output as a faithful description of reality. OpenAI's Codex addressed this with per-task sandboxing. Claude Code has no equivalent.

## What I'm NOT saying

Claude Code wins blind code quality evaluations. The model is excellent. The agentic runtime around it is not.

Anthropic's [September 2025 postmortem](https://www.anthropic.com/engineering/a-postmortem-of-three-recent-issues) disclosed 3 infrastructure bugs with more technical depth than any competitor offers. They document permission modes, deny rules, and hook-based interception in their official docs. The product isn't an unbounded free-for-all by design.

But the documented safety architecture doesn't guarantee that when Claude says "done," it actually is.

**Prompt-level rules cannot solve execution-level problems.** The community has already built the hooks that prove it. The question is whether Anthropic ships these as first-party features or leaves them as workarounds.

## What Anthropic should ship

**Now:** Edit read-back verification. Destructive command pre-authorization. Model downgrade notification.

**This quarter:** A tool-call-before-claim gate that cross-references output against the tool log. Structured summaries tagged VERIFIED / UNVERIFIED / SKIPPED.

**When ready:** An execution boundary. Per-step sandboxing. Version pinning.

My hooks prove the first tier works and costs nothing. The [community has built 5+ safety repos](https://github.com/kenryu42/claude-code-safety-net) to compensate for the rest.

The full taxonomy with all 16 sub-issues is here: [#32650](https://github.com/anthropics/claude-code/issues/32650).

*I used Claude Code to help write this post. The irony is not lost on me.*
