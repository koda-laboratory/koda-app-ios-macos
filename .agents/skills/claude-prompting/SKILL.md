---
name: claude-prompting
description: Transform a user's intent into an optimized prompt for Claude Fable 5, Opus 5, Sonnet 5, or Haiku 4.5 and recommend the best model and effort. Use when the user asks to write, improve, or optimize a Claude prompt, choose a Claude model or effort, or hand work to another Claude Code session. Do not use for Claude API system prompts or Codex prompts; use codex-prompting for Codex.
---

# Claude Prompting — model + effort recommendation and prompt crafting

Turn what the user wants to do into (a) a model + reasoning-effort recommendation and (b) a ready-to-paste prompt in English that follows that model's documented best practices.

Scope: exactly four models — **Claude Fable 5**, **Claude Opus 5**, **Claude Sonnet 5**, and **Claude Haiku 4.5** — and the Claude Code effort levels `low` / `medium` / `high` / `xhigh` / `max`. The first three take the effort dial; **Haiku 4.5 does not**, so it gets a model-only recommendation.

Language rule: talk to the user in **their language** (usually Spanish). The generated prompt is **always in English**.

## Koda context

- When the prompt targets this repository, inspect relevant project files in read-only mode before drafting. Do not carry assumptions from another repository into the prompt.
- Route app work through [ios-app-walkthrough](../ios-app-walkthrough/SKILL.md) and mention only the specialist project skills relevant to the task. Do not duplicate their detailed rules in the generated prompt.
- Treat `Koda/` as the maintained Swift source of the native iPhone + Mac app (one multiplatform target) and `../koda-backend` as the separate Supabase backend that owns the API contract. Never direct the target session to edit `.build/` or DerivedData.

## Workflow

### 1. Understand the intent

Extract from the user's request:
- **Goal** — what they want, and why / for whom (the motivation improves model performance; ask for it if absent).
- **Context** — repo, files, current state, prior attempts the target model can't infer on its own.
- **Constraints** — what must not change, conventions, tech limits.
- **Done criteria** — how success is verified (tests, observable behavior, deliverable shape).
- **Autonomy** — will the user watch the session, or is it fire-and-forget?

If something decisive is missing, ask at most 2–3 concise questions using the interaction mechanism available in the current client. If the task is clear enough to prompt well, proceed without asking.

**Two special cases at this step:**
- **Prompt-patching**: if the input is an *existing prompt* to improve ("improve this prompt", "this prompt is underperforming"), follow the Prompt-patching procedure in [references/recipes.md](references/recipes.md) instead of drafting from scratch — steps 2–5 below still apply (recommend model + effort, deliver in the standard format, plus the failure-mode diagnosis).
- **Multiple unrelated jobs**: if the request bundles unrelated asks, split them — one prompt per job, each with its own model/effort recommendation. Tell the user why.

### 2. Recommend model + effort

Read [references/model-selection.md](references/model-selection.md) and apply the decision matrix. **Always** present the recommendation explicitly with a 1–2 sentence justification — recommending model and effort is a hard requirement of this skill, even if the user already named a model (in that case validate or gently push back).

### 3. Load the model profile

Read the reference file for the chosen model plus the shared anatomy:
- [references/fable-5.md](references/fable-5.md)
- [references/opus-5.md](references/opus-5.md)
- [references/sonnet-5.md](references/sonnet-5.md)
- [references/haiku-4-5.md](references/haiku-4-5.md)
- [references/prompt-anatomy.md](references/prompt-anatomy.md)

### 4. Write the prompt

If the task matches an archetype in [references/recipes.md](references/recipes.md) (diagnosis, narrow fix, code review, research/recommendation), start from that recipe; otherwise draft from the anatomy skeleton. Apply the model-specific rules on top. Include **only** the model snippets that the task actually warrants — a short mechanical task does not need autonomy, memory, or delegation blocks. Prefer goal + constraints over step-by-step instructions.

Before delivering, check the draft against [references/antipatterns.md](references/antipatterns.md).

### 5. Deliver

Use this output shape, localizing the labels to the user's language while keeping the prompt in English unless requested otherwise:

1. **Recommendation**: `Model: <id> · Effort: <level>` plus a 1–2 sentence justification. For **Haiku 4.5**, omit effort and write `Model: claude-haiku-4-5`.
2. **Prompt**, in a fenced code block, ready to copy.
3. Optional single line: what to tweak if the user prefers another model.

## Maintenance note

The `references/` content is distilled from Anthropic's official model and prompting guides. When a model changes, update the matching profile and `model-selection.md` from `platform.claude.com`, never from memory.
