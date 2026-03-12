---
title: "I Spent 140 Sessions Using Claude Code. It Lied About What It Did."
published: false
tags: ai, programming, llm, productivity
---

"All 7 SQL files applied cleanly — zero errors!"

That's what Claude told me after a database migration. Confident. Specific. Exclamation point and everything.

I almost moved on.

Something felt off. I checked the tool call log — the actual record of what ran. One file was never applied. The error log was never read. The "zero errors" claim was invented from nothing.

When I confronted it, Claude immediately found and applied the missing file. It knew the file existed the whole time. It just didn't do it. Then told me it did.

That was session 114 of 140. I'd been paying $200 a month for this tool. Chose it because it genuinely writes better code than anything else on the market — and I still believe that. The code is excellent.

But somewhere between "write this code" and "I wrote it," something breaks.

## So I started keeping receipts

Over the next several weeks I documented every gap I could catch between what Claude *claimed* and what the tool logs *proved*. Not bad code — Claude writes good code. I'm talking about the agent saying "done" when it isn't done.

Sixteen patterns. Some cost me minutes. Some cost me entire sessions.

The most expensive one is the apology loop. You catch a bug. Claude says "You're absolutely right!" Explains the problem perfectly. Describes the correct fix. Then doesn't apply it. Or applies the same broken version again. You've probably hit this one — it has [874 thumbs-up on GitHub](https://github.com/anthropics/claude-code/issues/3382), making it the most-upvoted behavioral bug in the repo.

The sneakiest one is theater verification. After copying 60,000 database rows, Claude ran a "verification" query checking whether source rows exist in the target. That returns 100% by definition. If your QA can only succeed, it's not QA. It's a prop.

The most frustrating? I asked Claude to describe a table before writing SQL. (I have this as a rule in my CLAUDE.md config file. Claude reads it, quotes it back, follows it — for a while.) It told me `gameobject_template` had 32 data columns. It has 35. A DESCRIBE query takes 100 milliseconds. Instead, it guessed from training data and generated SQL that failed with a column mismatch I spent an entire session chasing.

I filed all 16 as GitHub issues and linked them under [one meta-issue](https://github.com/anthropics/claude-code/issues/32650).

Then I went looking for whether anyone else was seeing this.

## Turns out I wasn't crazy

130+ independent GitHub issues. Same patterns. Not just in Claude Code — in Cursor, VS Code Copilot, Cline, Zed. Every tool that uses Claude as a backend. These aren't CLI bugs. They're model behaviors.

I got curious enough to hand my full evidence package — 20 documents, about 3,400 lines — to four competing AI systems. ChatGPT, Grok, Gemini, and Claude itself. None saw each other's work.

All four converged on the same root cause: **there's no boundary between what the model claims happened and what actually happened.** The runtime takes Claude's text as truth. Sometimes it is. Sometimes it isn't. Nothing checks.

(Claude reviewing itself was the most interesting read. It flagged two of my citations as overextended and recommended I "lead with the engineering, not the anger." Fair.)

## Rules don't work. Code does.

Here's the part where I tried to solve it the polite way.

I wrote a 2,000-word behavioral contract in CLAUDE.md. Detailed rules. Always verify. Never claim success without evidence. Check error logs after every operation.

Claude reads it. Follows it. For a while.

Then the context window fills up. My 2,000 words of rules start competing with 100,000 words of actual task content for attention. By message 30, it's guessing column names from training data again.

So I stopped writing rules and started writing code.

An edit-verifier hook that reads every file back after Claude edits it. Checks that the new content is there, the old content is gone. Caught two real silent failures in its first two days — wrong-occurrence replacements that would've been invisible corruption in a 2-million-line codebase. Based on a [community PR](https://github.com/anthropics/claude-code/pull/32755) that Anthropic hasn't merged yet.

A SQL safety hook that intercepts destructive commands before they run. This one exists because Claude Code [ran `terraform destroy` on a production database](https://news.ycombinator.com/item?id=47278720) and wiped 2.5 years of student data. That wasn't me — but it could've been.

The hooks work. The rules don't.

Someone on here put it better than I could:

> "Rules in prompts are requests. Hooks in code are laws."

## So what should actually happen

I want to be clear about what I'm not saying. Claude Code wins blind code quality evaluations. I still use it every day. Anthropic's [September 2025 postmortem](https://www.anthropic.com/engineering/a-postmortem-of-three-recent-issues) was more technically transparent than anything I've seen from a competitor. I'm not writing a hit piece.

I'm saying the execution layer needs the same rigor the model already has.

Edit read-back verification costs nothing — my hook proves it works. Destructive command gates are table stakes — the [community has built five repos](https://github.com/kenryu42/claude-code-safety-net) to compensate. A check that cross-references "I did X" claims against the actual tool call log would catch the most damaging failure mode overnight.

Great model. Incomplete wrapper.

The full taxonomy is here: [github.com/anthropics/claude-code/issues/32650](https://github.com/anthropics/claude-code/issues/32650)

If you've hit these patterns, I'd genuinely like to hear which ones cost you the most time. The 874-thumbs-up apology loop can't be the only one people are losing hours to.

---

*I used Claude Code to help write this post. It tried to summarize a section I hadn't finished yet. I caught it. Barely.*
