# Roadmap

Post-MVP directions for Simple Usage Bar. **V1 stays Grok-only and CLI-auth-only** per [design.md](design.md).

---

## Near term (after P2 polish)

| Item | Notes |
|------|--------|
| README | **Done** (P2) |
| Threshold notifications | Optional macOS notification at 80% / 100% used |
| Agent stdio billing | Prefer `x.ai/billing` when Grok Build exposes it on agent-stdio |
| Secondary buckets | Protobuf field-7 repeated windows — **plausible** per-product breakdown (Build / Chat / Imagine / …); keep exploratory until type ids are mapped against grok.com Usage UI |

---

## Medium term

| Item | Notes |
|------|--------|
| Second provider | e.g. Claude Code or Codex — new `UsageProvider`, shared menubar shell |
| Settings window | Refresh interval, color thresholds, launch-at-login, percent used vs remaining |
| Merge / multi-icon | Only if multi-provider ships |
| Developer ID + notarization | For shareable `.app` |
| Sparkle updates | After notarized releases exist |

---

## Explicitly not planned

- **OIDC token refresh in-app** — out of scope. Primary use is alongside Grok Build, which refreshes `~/.grok/auth.json`; the app re-reads on file change. Idle-only expiry is not a product concern.
- Becoming a full CodexBar-style multi-provider suite as a primary goal
- Browser Keychain cookie scraping as a product pillar
- Cloud backend or account system for Simple Usage Bar itself
- Non-macOS v1

---

## Success metrics (informal)

1. Glanceable accuracy vs grok.com Usage for personal SuperGrok-style accounts.
2. Zero prompts for Full Disk Access or browser Keychain.
3. Cold start to first number &lt; 2 seconds on a normal network when credentials are warm.
4. No crashes when CLI is uninstalled or logged out.
