# Project Knowledge Index

Single source of truth for major project documents. Agents and humans should consult this index before high-level design or architecture work.

## Product & architecture

| Document | Purpose |
|----------|---------|
| [docs/design.md](docs/design.md) | **Primary design document** — goals, architecture, data model, UI, security, testing, MVP milestones |
| [docs/grok-provider.md](docs/grok-provider.md) | Grok Code provider deep dive — CLI auth schema, billing endpoint, protobuf map, failure modes |
| [docs/roadmap.md](docs/roadmap.md) | Near-term roadmap beyond MVP (providers, packaging, polish) |

## Agent / process

| Document | Purpose |
|----------|---------|
| [AGENTS.md](AGENTS.md) | Agent workflow rules (branching, validation, tooling preferences) |

## Status

- **Phase:** P1 live Grok usage via CLI auth + GetGrokCreditsConfig; P2 polish next.
- **V1 scope:** macOS menubar app; Grok Code only; CLI auth only.
- **App sources:** `SimpleUsageBar/` + `SimpleUsageBar.xcodeproj` + `SimpleUsageBarTests/`
