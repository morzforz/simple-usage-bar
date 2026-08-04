# Simple Usage Bar — Design Document

**Status:** Accepted for implementation  
**Date:** 2026-08-02  
**Product name:** Simple Usage Bar  
**Bundle ID (proposed):** `com.andrewcoleman.SimpleUsageBar`

---

## 1. Problem & motivation

Subscription AI coding tools expose finite usage pools (often weekly) that reset on a schedule. Hitting the limit mid-task is painful; checking a website or dashboard breaks flow.

**Simple Usage Bar** is a tiny macOS menubar app that keeps the **current usage percentage** and **reset date/time** visible at a glance. V1 targets **Grok Code** (Grok Build CLI) and reuses the **CLI’s existing OAuth credentials** rather than introducing a separate web login.

---

## 2. Goals and non-goals

### Goals (v1)

1. Show Grok subscription **used %** in the menubar continuously.
2. Surface **reset time** (absolute + relative countdown) in a popover.
3. Authenticate using **only** the Grok Build CLI credential store (`~/.grok/auth.json`).
4. Stay lightweight: no Dock icon, low memory, no background disk crawling.
5. Structure code with a small **Provider** interface so additional services can be added later without a rewrite.

### Non-goals (v1)

- Multi-provider support (interface only; no second implementation).
- Browser cookies, Keychain browser import, or in-app OAuth / web login.
- Spending charts, local session cost aggregation, or WidgetKit widgets.
- Auto-updating installer (Sparkle), notarized distribution pipeline.
- Windows / Linux.
- Implementing `grok login` inside the app.
- Feature parity with multi-provider suites (e.g. CodexBar).

---

## 3. User stories

1. **As a Grok Code user**, I open my laptop and immediately see how much of my weekly pool I have used.
2. **As a user mid-task**, I click the menubar item and see when usage resets so I can decide whether to continue or wait.
3. **As a user who only uses the CLI**, I never have to sign into a browser for this app; if I am logged into `grok`, the app works.
4. **As a user who is logged out**, I see a clear message: run `grok login` — not a cryptic network error.
5. **As a future maintainer**, I can add another provider by implementing one protocol without touching the menubar shell.

---

## 4. Competitive context

[CodexBar](https://github.com/steipete/CodexBar) already tracks many AI coding providers, including Grok (CLI billing RPC + grok.com browser-session fallback).

**Differentiation for this project:**

| Dimension | Simple Usage Bar | CodexBar (context) |
|-----------|------------------|--------------------|
| Scope | Grok-first, deliberately small | Many providers |
| Auth (Grok) | CLI auth only | CLI + browser cookies |
| UI | Minimal menubar + popover | Rich multi-provider UI, charts, widgets |
| Goal | One glance, one service done well | Universal quota cockpit |

We may learn from public reverse-engineering notes (auth path, gRPC-web endpoint shape) but own our parser, UX, and scope. We are not a fork.

---

## 5. Auth model

### Principle

**Reuse CLI auth; never invent a second login.**

### Credential source

| Item | Detail |
|------|--------|
| Default path | `~/.grok/auth.json` |
| Override | `$GROK_HOME/auth.json` if `GROK_HOME` is set |
| Permissions | Typically `0600`; read-only for this app |
| Written by | `grok login` / CLI refresh — **not** this app |

### What we read

From the preferred OIDC entry (`https://auth.x.ai::<client-id>` preferred over legacy `https://accounts.x.ai/sign-in`):

- `key` — bearer access token (secret; never log)
- `expires_at` — ISO-8601; skip expired tokens for API calls
- `email`, `user_id`, `team_id`, `principal_type`
- `auth_mode`, display name fields as optional identity chrome

### What we never do (v1)

- Store passwords or browser cookies
- Write or mutate `auth.json`
- Automatically run `grok login`
- Implement OIDC token refresh (CLI owns refresh when the user uses Grok)

### Unauthenticated UX

If the file is missing, unreadable, empty, or all tokens are expired:

- Menubar: `G —` or a muted icon
- Popover: “Not signed in. Run `grok login` in Terminal, then Refresh.”
- Optional action: copy `grok login` to clipboard

See [grok-provider.md](grok-provider.md) for the full auth schema.

---

## 6. Data model & provider interface

### `UsageSnapshot`

Canonical UI-facing model (Swift-oriented names):

| Field | Type | Notes |
|-------|------|--------|
| `providerId` | `String` | e.g. `"grok"` |
| `displayName` | `String` | e.g. `"Grok"` |
| `usedPercent` | `Double` | 0…100+ (clamp for display; allow >100 if API returns it) |
| `resetsAt` | `Date?` | Period end / next reset |
| `periodStart` | `Date?` | Optional; for window label |
| `windowLabel` | `WindowLabel` | `.weekly` / `.monthly` / `.credits` / `.unknown` |
| `accountEmail` | `String?` | From auth file |
| `principalType` | `String?` | `User` / `Team` |
| `fetchedAt` | `Date` | Local fetch time |
| `source` | `UsageSource` | `.billingApi` / `.agentRpc` / `.mock` |

**Percent semantics (v1):** display **used %** of the subscription credit pool (not remaining %). Color thresholds based on used %:

- Green: `&lt; 70%`
- Yellow: `70% … &lt; 90%`
- Red: `≥ 90%`

### `AppState`

```text
ready(UsageSnapshot)
stale(UsageSnapshot, lastError: String)   // show last-good + warning
unauthenticated
loading
error(String)                             // no last-good snapshot
teamUnsupported                           // principal_type Team when API rejects
```

### `Provider` protocol

```swift
protocol UsageProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func isConfigured() -> Bool
    func fetchUsage() async throws -> UsageSnapshot
}
```

V1 ships a single `GrokProvider`. The app model holds `[any UsageProvider]` but only registers Grok.

---

## 7. Grok implementation (summary)

**Primary path (v1):**

1. Read credentials from CLI auth file.
2. `POST` empty gRPC-web body to  
   `https://grok.com/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig`  
   with `Authorization: Bearer <key>`.
3. Parse protobuf response for **credit usage percent** and **billing period end**.
4. Map into `UsageSnapshot` with `windowLabel` inferred from period length (~7 days → weekly).

**Validated:** CLI bearer works against this endpoint without browser cookies (probed 2026-08-02).

**Future path:** ACP JSON-RPC `x.ai/billing` via `grok agent stdio` — currently returns `Method not found` on Grok Build `0.2.x`; revisit when xAI exposes it.

**Out of scope:** browser cookie fallback.

Full wire format, field map, and failure classification: [docs/grok-provider.md](grok-provider.md).

---

## 8. UI / UX

### App presentation

- **LSUIElement** accessory app (no Dock icon).
- Single `NSStatusItem` in the menu bar.
- Primary interaction: click → **popover** (SwiftUI content hosted in `NSPopover` or equivalent).
- No main window in v1 (optional Settings deferred to P2+).

### Menubar

| State | Example title / appearance |
|-------|----------------------------|
| Ready | `G 43%` (or compact bar glyph + percent) |
| Stale | `G 43%` + dimmed / warning tint |
| Unauthenticated | `G —` |
| Loading (first launch) | `G …` |
| Error | `G !` |
| High usage (≥90%) | Red-tinted text or icon |

Tooltip example: `Grok · 43% used · resets in 6h`.

### Popover content

1. Provider name (“Grok”)
2. Large used % + horizontal usage bar
3. Window label (“Weekly”) + reset: absolute local time + relative (“in 5h 12m”)
4. Account email (if known)
5. Source line: “CLI auth · refreshed 2m ago”
6. Actions:
   - **Refresh**
   - **Open usage on grok.com** → `https://grok.com/?_s=usage` (or billing deep link)
   - **Quit Simple Usage Bar**

### Empty / error copy

| State | Copy |
|-------|------|
| No auth file | “Grok CLI is not signed in. Run `grok login`, then Refresh.” |
| Expired token | “CLI credentials expired. Run `grok` or `grok login` to refresh, then Refresh.” |
| Network error | “Could not reach Grok billing. Showing last known usage.” (if stale) |
| Parse error | “Unexpected billing response. Try again after a CLI update.” |
| Team unsupported | “Team usage is not available from this billing surface yet.” |

### Accessibility

- Status item title remains readable text (not icon-only by default).
- Popover uses standard Dynamic Type–friendly SwiftUI controls.
- Color is never the only signal (include numeric %).

---

## 9. Refresh & lifecycle

### Triggers

| Event | Behavior |
|-------|----------|
| App launch | Immediate fetch |
| Timer | Every **5 minutes** while app is running |
| Manual Refresh | Immediate (respect min interval) |
| `auth.json` change | Debounced re-read + fetch (DispatchSource / FSEvents) |
| Network path restored | Fetch once |
| Wake from sleep | Fetch once |

### Rate limits (client-side)

- **Minimum interval** between network fetches: **30 seconds** (manual spam protection).
- Single-flight: overlapping `fetchUsage` calls coalesce to one in-flight task.
- Do not poll while snapshot is already refreshing.

### Process lifecycle

- Launch at Login: optional via `SMAppService.mainApp` (P2).
- Quit from popover only (no Dock).
- No background XPC helper in v1.

---

## 10. Security & privacy

1. **Secrets:** Access tokens stay in memory only as needed for the request; never written to logs, analytics, or disk by this app.
2. **Network:** Only required hosts for Grok billing (e.g. `grok.com`). No third-party telemetry in v1.
3. **Permissions:** No Full Disk Access, Screen Recording, Accessibility, or browser Keychain access.
4. **Filesystem:** Read only the known auth path (and optional future local session paths for diagnostics — not v1).
5. **Unofficial API:** Billing RPC is reverse-engineered / best-effort. Document this in README and accept breakage on xAI changes.
6. **Sandox:** Prefer non-sandboxed or carefully entitled app for reading `~/.grok` outside the container; if App Store is ever pursued, revisit auth discovery (not a v1 goal).

---

## 11. Tech stack & project layout

### Stack

| Choice | Decision |
|--------|----------|
| Language | Swift 6 |
| UI | SwiftUI for popover; AppKit `NSStatusItem` for menubar |
| Concurrency | `async`/`await`, `@MainActor` for UI model |
| Networking | `URLSession` |
| Protobuf | Hand-rolled minimal parser for known fields (avoid full protoc dependency unless needed) |
| Min OS | macOS 14 (Sonoma) |
| Packaging | Xcode app target; ad-hoc sign for local runs |

### Proposed layout

```text
simple-usage-bar/
  INDEX.md
  AGENTS.md
  docs/
    design.md
    grok-provider.md
    roadmap.md
  SimpleUsageBar/                 # app sources
    App/
      SimpleUsageBarApp.swift
      AppDelegate.swift           # status item ownership if needed
    Model/
      AppModel.swift
      UsageSnapshot.swift
      AppState.swift
    Providers/
      UsageProvider.swift
      Grok/
        GrokProvider.swift
        GrokAuthStore.swift
        GrokBillingClient.swift
        GrokCreditsProtoParser.swift
    UI/
      StatusItemController.swift
      PopoverView.swift
    Support/
      RefreshScheduler.swift
      AuthFileWatcher.swift
  SimpleUsageBarTests/
    GrokCreditsProtoParserTests.swift
    GrokAuthStoreTests.swift
  README.md                       # added at implementation kickoff
```

Exact Xcode project generation is an implementation task (P0).

---

## 12. Testing strategy

| Layer | What |
|-------|------|
| Unit | Auth JSON parsing (fixtures with fake tokens, no real secrets) |
| Unit | gRPC-web frame unwrap + protobuf field walk against **checked-in binary fixtures** (captured responses, redacted) |
| Unit | Window label inference from period length |
| Unit | Percent clamping / color threshold helpers |
| Integration (manual) | Live fetch with developer’s real `auth.json` (never committed) |
| UI | SwiftUI previews for ready / stale / unauthenticated / error |

CI (later): `xcodebuild test` on macOS runner; no live network in CI.

---

## 13. Build, run, packaging

### V1 developer loop

1. Open Xcode project / workspace.
2. Run scheme **SimpleUsageBar**.
3. Status item appears; requires existing `grok login` session for live data.

### Distribution (deferred)

- Ad-hoc or Developer ID signed `.app` zip.
- Notarization + Sparkle: roadmap, not MVP.

---

## 14. MVP milestones

### P0 — Shell

- Xcode app, LSUIElement, status item.
- Popover with **mock** `UsageSnapshot`.
- Quit action.
- Project builds cleanly.

### P1 — Live Grok usage

- `GrokAuthStore` + `GrokBillingClient` + proto parser.
- Real used % + reset time in menubar and popover.
- Unauthenticated / error states.
- Manual refresh + 5-minute timer.
- Unit tests for parser + auth reader.

### P2 — Polish

- Auth file watcher.
- Color thresholds.
- Stale-while-revalidate UX.
- Launch at Login toggle (simple).
- README for users (install, `grok login` prerequisite).

### P3+ — See [roadmap.md](roadmap.md)

---

## 15. Risks & mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Undocumented billing API / protobuf drift | App shows parse errors | Fixture tests; defensive parser; clear error copy |
| Access token expires without CLI use | False “logged out” | Messaging; optional future OIDC refresh; file watcher after user re-logins |
| Team principals unsupported | No usage for team accounts | Detect `principal_type`; dedicated state |
| xAI rate-limits or blocks clients | Fetch failures | Conservative poll; User-Agent identifiable; backoff |
| ToS / unofficial API | Policy risk | Best-effort personal tool; no credential exfiltration; document unofficial status |
| Name / brand | Confusion | Keep product name generic (“Simple Usage Bar”); do not imply affiliation with xAI |

---

## 16. Open questions

Resolved for v1 with defaults:

| Question | Decision |
|----------|----------|
| Stack? | Swift 6 + SwiftUI + AppKit status item |
| Used vs remaining %? | **Used %** |
| Web auth? | **No** |
| Multi-provider UI? | **No** (protocol only) |
| Product name? | **Simple Usage Bar** |

Deferred:

1. Should we implement OIDC refresh ourselves if tokens expire while CLI is idle?
2. Official public usage API from xAI — switch when/if available.
3. Whether multi-bucket percents in the protobuf should surface as secondary lines later.

---

## 17. Implementation order (after this doc)

1. P0 app skeleton on `feature/app-shell` (or similar).
2. P1 Grok provider + tests on `feature/grok-billing`.
3. P2 polish.
4. Merge to `main` only when validation (build + tests) passes per `AGENTS.md`.

---

## Related documents

- [grok-provider.md](grok-provider.md) — auth & billing detail
- [roadmap.md](roadmap.md) — post-MVP
- [INDEX.md](../INDEX.md) — project knowledge index
