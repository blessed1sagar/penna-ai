# Domain Docs

This repo uses a **single-context** layout.

- `docs/CONTEXT.md` — project domain language and key concepts
- `docs/adr/` — Architecture Decision Records (one file per decision)

## Consumer rules for skills

1. Read `docs/CONTEXT.md` first to understand domain language before suggesting changes.
2. Read all files under `docs/adr/` to understand past architectural decisions.
3. Prefer terms defined in `CONTEXT.md` over generic language when writing issues, tests, or architecture suggestions.
4. When a suggestion conflicts with an existing ADR, flag it explicitly rather than silently overriding it.
