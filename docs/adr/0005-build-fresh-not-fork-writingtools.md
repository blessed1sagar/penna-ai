# Build fresh, do not fork WritingTools

Research found theJayTea/WritingTools (GPL-3.0, native Swift, Ollama+MLX) already implements ~85% of our design, and forking it would be the fastest path to v1. We chose to build fresh anyway. WritingTools is a broad, feature-rich app; our product is deliberately narrow (one hotkey, two modes, a focused floater, a draft composer). Starting from their codebase would mean inheriting and then stripping complexity we don't want, and it constrains the project under GPL-3.0 copyleft. Building from zero keeps the app minimal, gives full ownership of every decision, and leaves licensing open.

## Consequences

- WritingTools and Enchanted/Ollamac are treated as **reference architecture** (selection-capture layer, Swift→Ollama networking), not a code base. We may read them for patterns; we do not copy GPL code.
- We accept a slower start in exchange for a smaller, fully-understood codebase — consistent with the project's "simple and efficient" goal.
- Apple's built-in Writing Tools (free, on-device on M2) overlaps our grammar-fix capability. Our differentiation is the draft-message composer and a minimal dedicated floater, not raw correction capability.
