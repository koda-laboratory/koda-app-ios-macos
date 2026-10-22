# Model + effort selection matrix

Distilled from Anthropic's official model documentation (2026-08). Four candidate models only.

## Step A — pick the model

| Task signals | Model | Pricing (per MTok in/out) |
|---|---|---|
| Hardest reasoning; long-horizon autonomous work (overnight coding runs, large migrations/refactors that must complete without correction); complex architecture design; deep research; the problems previous models couldn't solve; sustained multi-agent orchestration | `claude-fable-5` | $10 / $50 |
| **Default.** Complex agentic coding, multi-hour work, large refactors, code review, deep debugging, research, and knowledge work where Fable-tier capability is unnecessary | `claude-opus-5` | $5 / $25 |
| Well-specified implementation work, fast turnaround, cost-sensitive or high-volume tasks, mechanical-but-nontrivial changes (renames, boilerplate, test scaffolding, straightforward features). Near-Opus quality on coding/agentic at Sonnet cost | `claude-sonnet-5` | $3 / $15 |
| Simple, high-volume, latency-critical, well-scoped tasks with no hard reasoning — classification, extraction, format conversion, quick factual lookups, short explanations of standard concepts, cheap sub-agents/workers. Fastest and cheapest; below the Sonnet tier | `claude-haiku-4-5` | $1 / $5 |

Tie-breakers:
- If the user will iterate interactively and latency matters → step down a tier.
- If the task is autonomous, ambiguous, or failure is expensive → step up a tier.
- Don't recommend Fable 5 by default — it is for tasks above what Opus 5 handles well and costs 2× Opus.
- Haiku 4.5 is the floor: pick it only when the task genuinely doesn't need Sonnet-or-better reasoning (it's a smaller 200K-context / 64K-output model). If a Haiku task turns out to need real reasoning depth, step up to Sonnet 5 rather than forcing it.

## Step B — pick the effort

Fable 5, Opus 5, and Sonnet 5 support `low` / `medium` / `high` / `xhigh` / `max`. **Haiku 4.5 is the exception: it has no effort dial** — the effort levels error on it. Haiku uses classic extended thinking (a thinking budget, off by default), so when you recommend Haiku, give a **model-only** recommendation (no effort level) and note that its reasoning depth is fixed; if the task needs more, that's the signal to step up to Sonnet 5.

| Effort | Use for |
|---|---|
| `xhigh` | The hardest coding and agentic tasks (what Claude Code defaults to for those). Requires room to think — long autonomous work. |
| `high` | General default; the minimum for intelligence-sensitive work. Often the sweet spot of quality vs token efficiency. |
| `medium` | Routine but non-trivial work where cost/latency matters; on Sonnet 5, `medium` ≈ Sonnet 4.6 at `high`. |
| `low` | Short, scoped, mechanical, latency-sensitive tasks that aren't intelligence-sensitive. Fewer/more-consolidated tool calls, less preamble. |
| `max` | Correctness matters more than cost or latency. Warn the user: diminishing returns and overthinking risk — test before committing. |

Per-model nuances:
- **Fable 5**: lower efforts (`low`/`medium`) still perform very well — often above previous models' `xhigh` — so consider them for routine work. At higher effort it can over-gather context on simple tasks. Turns can run many minutes at high effort.
- **Opus 5**: start at its `high` default, use `low` or `medium` when evaluations show they preserve quality, and step up to `xhigh` for the most demanding coding and agentic work.
- **Sonnet 5**: respects effort strictly, especially at the low end — at `low`/`medium` it scopes work to exactly what was asked. If shallow reasoning shows up, raise effort rather than prompting around it. First Sonnet with `xhigh`.
- **Haiku 4.5**: no effort dial (it errors); classic extended thinking, off by default. Don't recommend an effort level for it — recommend the model alone. Smaller envelope (200K context / 64K max output). It's for bounded, simple work; escalate to Sonnet 5 the moment a task needs real reasoning.

## Calibrated examples

| Task | Recommendation |
|---|---|
| "Migrate the whole persistence layer to SwiftData, overnight, unattended" | Fable 5 · `xhigh` — long-horizon autonomous, expensive to get wrong |
| "Design the sync architecture between the iOS app and the new backend, weigh trade-offs" | Fable 5 · `high` (or Opus 5 · `xhigh` if cost-sensitive) |
| "Review this PR for real bugs" | Opus 5 · `high` — strong precision and recall at the default effort |
| "Implement this well-specced endpoint + tests" | Sonnet 5 · `high` |
| "Rename module X across the repo and fix imports" | Sonnet 5 · `low` — mechanical, well-specified |
| "Debug this flaky test that nobody can reproduce" | Opus 5 · `xhigh` — hard debugging, needs depth |
| "Classify these 5k support tickets by category" | Haiku 4.5 (no effort dial) — simple, high-volume, latency/cost-sensitive |
| "Explain what Parquet is in one paragraph" | Haiku 4.5 (no effort dial) — standard concept, quick lookup; Sonnet 5 · `medium` if you want more depth |
