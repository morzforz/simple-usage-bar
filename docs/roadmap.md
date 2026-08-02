# Roadmap

Post-MVP directions for Simple Usage Bar. **V1 stays Grok-only and CLI-auth-only** per [design.md](design.md).

---

## Near term (after P2 polish)

| Item | Notes |
|------|--------|
| README | Install, `grok login` prerequisite, unofficial API disclaimer |
| Threshold notifications | Optional macOS notification at 80% / 100% used |
| OIDC refresh (optional) | If idle token expiry is painful, implement refresh using CLI’s OIDC client metadata — only with careful secret handling |
| Agent stdio billing | Prefer `x.ai/billing` when Grok Build exposes it on agent-stdio |
| Secondary buckets | Surface protobuf field-7 windows if they prove user-meaningful |

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
