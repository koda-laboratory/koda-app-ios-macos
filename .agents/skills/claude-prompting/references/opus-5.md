# Claude Opus 5 — prompting profile

Anthropic's default for complex agentic coding and enterprise work. Use it for multi-hour autonomous work, large refactors, difficult debugging, code review, deep research, and document-heavy tasks that do not require Fable 5.

## Behavioral profile

- Strong on complete multi-file and end-to-end work; provide the full task specification up front.
- High precision and recall in code review. Conservative filters such as “only high severity” reduce coverage.
- Strong at `low` and `medium`; start at the `high` default and use `xhigh` for the most demanding coding and agentic work.
- More verbose and more likely to narrate progress than prior Opus models.
- Self-verifies and self-corrects strongly; inherited “double-check everything” scaffolding can cause over-verification.
- Delegates readily. Limit subagents to sizeable, genuinely independent workstreams.

## Prompting rules

1. State the complete goal, constraints, scope, and completion bar up front.
2. Constrain narrow tasks explicitly; let it make routine choices without silently widening the request.
3. Specify the desired cadence and length of user-visible progress updates.
4. Remove redundant verification or verifier-agent instructions unless the task has a concrete, unusual validation requirement.
5. Keep thinking enabled and tune cost with effort instead of disabling thinking.

## Snippets

Include only the snippets the task needs.

**Scope discipline** — for narrow work:
> Deliver what was asked at the intended scope. Make routine judgment calls yourself, and ask only when different readings would lead to materially different work. If a better approach exists, mention it briefly and continue with the requested task rather than silently widening or transforming it.

**Progress cadence** — for tool-heavy work:
> Before the first tool call, state the immediate objective in one sentence. Update only when you find something important, change direction, or become blocked. Finish by leading with the outcome.

**Subagent control** — when delegation is available:
> Delegate only sizeable workstreams that are genuinely independent and parallelizable. Do not delegate a task you can finish in a handful of tool calls, and do not spawn agents solely to re-check your own work.

**Review coverage** — when the user wants broad bug discovery:
> Report every issue you find and include confidence and severity. Rank or filter findings only after completing the coverage pass.

**Output length** — for written deliverables:
> Match the length to the substance. Do not add filler sections, redundant summaries, or boilerplate.
