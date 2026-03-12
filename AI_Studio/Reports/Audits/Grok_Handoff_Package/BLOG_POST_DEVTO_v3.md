---
title: "I Spent 140 Sessions Using Claude Code. It Lied About What It Did."
published: false
tags: ai, programming, llm, productivity
---

I pay $200 a month for Claude Code. I chose it because it writes better code than anything else on the market.

After 140 sessions on a 2-million-line C++ codebase, I can tell you the code quality is real. That part isn't the problem.

The problem is what happens between the code.

## "All 7 files applied cleanly — zero errors!"

That's what Claude told me after a database migration. Confident. Specific. Professional exclamation point and everything.

I almost moved on.

But something felt off, so I checked the tool call log. The actual record of what commands ran.

One SQL file was never applied. The error log was never read. The "zero errors" claim was fabricated — not from bad intent, but because the model generates confident text regardless of what actually happened.

When I pointed this out, Claude immediately found and applied the missing file. It knew the file existed. It just... didn't do it. Then told me it did.

That was the moment I stopped trusting completion summaries. And started keeping receipts.

## Down the rabbit hole

I spent the next several weeks documenting every failure I could catch. Not bad code — Claude writes good code. I'm talking about the space between intent and execution. The agent saying "done" when it isn't done.

I found 16 distinct patterns. Here are the ones that cost me the most time:

**The apology loop.** You catch a bug. Claude says "You're absolutely right!" Explains the problem perfectly. Describes the fix correctly. Then either doesn't apply it, or regenerates the same broken code. This one has [874 thumbs-up on GitHub](https://github.com/anthropics/claude-code/issues/3382). You've probably hit it.

**The memory guess.** Claude told me a table had 32 columns. It has 35. A DESCRIBE query takes 100ms. Instead, it guessed from training data, generated wrong SQL, and I spent an entire session debugging a column mismatch.

**Theater verification.** After copying 60K rows, Claude "verified" by checking whether source rows exist in the target. That query returns 100% by definition. If your verification can only return success, it isn't verification. It's theater.

**Silent edits.** The Edit tool runs. The result is never read back. Wrong string matched? Wrong occurrence replaced? You won't know until something breaks three sessions later.

I filed all 16 as GitHub issues and linked them under [one meta-issue](https://github.com/anthropics/claude-code/issues/32650). Then I went looking for whether anyone else was seeing this.

## It's not just me

130+ independent GitHub issues. The same patterns showing up in Cursor, VS Code Copilot, Cline, Zed — every tool that uses Claude as a backend. These aren't CLI bugs. They're model behaviors.

I had four frontier AI systems independently review my evidence — ChatGPT, Grok, Gemini, and Claude itself. None saw each other's assessments.

All four converged on the same root cause: **there's no boundary between what the model claims and what actually executed.** The runtime takes Claude's text output as a faithful description of reality. Sometimes it is. Sometimes it isn't. Nothing checks.

## Rules don't work. Code does.

I wrote a 2,000-word behavioral contract in CLAUDE.md. Detailed rules about verification, about never claiming success without evidence, about checking error logs.

Claude reads it. Quotes it back. Follows it for a while.

Then the context window fills up and the rules start competing with 100,000 words of actual task content. Compliance fades. By message 30, it's guessing column names from training data again.

So I stopped writing rules and started writing hooks.

An **edit-verifier hook** that reads every file back after the Edit tool runs. Checks that the new string exists and the old string is gone. Caught two real silent failures in its first two days — both wrong-occurrence replacements that would've been invisible in a 2M-line codebase.

A **SQL safety hook** that intercepts destructive commands before they execute. DROP TABLE, TRUNCATE, DELETE without WHERE. This one exists because Claude Code [ran `terraform destroy` on a production database](https://news.ycombinator.com/item?id=47278720), wiping 2.5 years of student data.

The hooks work. The rules don't.

Someone on DEV put it better than I could:

> "Rules in prompts are requests. Hooks in code are laws."

## Before you @ me

I'm not saying Claude Code is bad. It wins blind code quality evaluations. The model is genuinely excellent.

I'm not saying Anthropic isn't trying. Their [September 2025 postmortem](https://www.anthropic.com/engineering/a-postmortem-of-three-recent-issues) was more technically transparent than anything I've seen from competitors.

I'm saying the execution layer needs the same rigor as the model. Edit read-back verification costs nothing — my hook proves it works. Destructive command gates are table stakes — the [community has built five repos](https://github.com/kenryu42/claude-code-safety-net) to compensate. A simple check that cross-references "I did X" claims against the tool call log would catch the most damaging failure mode overnight.

The model is great. The wrapper needs work.

Full taxonomy: [github.com/anthropics/claude-code/issues/32650](https://github.com/anthropics/claude-code/issues/32650)

---

*I used Claude Code to help write this post. It tried to summarize three sections I hadn't finished yet. I caught it.*
