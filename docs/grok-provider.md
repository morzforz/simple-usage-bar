# Grok Code Provider — Technical Reference

**Status:** Design reference for implementation  
**Last validated:** 2026-08-02  
**CLI version probed:** Grok Build `0.2.118`  
**Related:** [design.md](design.md)

This document describes how Simple Usage Bar obtains **identity** and **subscription usage** for Grok Code (Grok Build CLI) using **CLI authentication only**.

> **Caveat:** The billing endpoint and protobuf layout are **unofficial / reverse-engineered**. They can change without notice. Treat parsers as best-effort and keep fixtures + defensive decoding.

---

## 1. Identity & credentials

### Location

| | |
|--|--|
| Default file | `~/.grok/auth.json` |
| Override | `$GROK_HOME/auth.json` |
| Typical mode | `0600` |
| Writer | Grok Build CLI (`grok login`, token refresh) |
| Reader (this app) | Read-only |

### Top-level shape

JSON object whose **keys** are OIDC scope identifiers:

```text
https://auth.x.ai::<client-id>     ← preferred (current SuperGrok / Grok Build OIDC)
https://accounts.x.ai/sign-in      ← legacy (if present)
```

### Per-entry fields

| Field | Required for usage fetch | Description |
|-------|--------------------------|-------------|
| `key` | Yes | Bearer access token (JWT) |
| `expires_at` | Yes | ISO-8601 timestamp; do not send token if expired |
| `refresh_token` | No (v1) | Present; CLI owns refresh |
| `email` | No | Display in popover |
| `user_id` | No | Diagnostics |
| `team_id` | No | Display / team handling |
| `principal_type` | No | `User` or `Team` (older files may omit) |
| `auth_mode` | No | e.g. `oidc` |
| `first_name` / `last_name` | No | Display chrome |
| `oidc_issuer` | No | e.g. `https://auth.x.ai` |
| `oidc_client_id` | No | Matches key suffix |
| `create_time` | No | Credential creation |
| `coding_data_retention_opt_out` | No | Privacy preference; ignore for usage |

### Selection algorithm

1. Resolve auth path (`GROK_HOME` or `~/.grok`).
2. If file missing → unauthenticated.
3. Parse JSON object.
4. Prefer entries whose key starts with `https://auth.x.ai::`.
5. Else fall back to any entry with a non-empty `key`.
6. Among candidates, prefer non-expired (`expires_at` > now).
7. If only expired entries exist → unauthenticated (expired).
8. Never log `key` or `refresh_token`.

### Token lifetime

Observed access-token lifetime is on the order of **hours** (not multi-day). When the user runs the Grok CLI, it refreshes credentials in place. This app **does not** implement refresh in v1.

### Login flows (user-facing, outside the app)

```bash
grok login            # interactive OAuth
grok login --oauth    # force OAuth via auth.x.ai
grok login --device-auth   # device code (headless)
grok logout           # clears credentials
```

---

## 2. Usage data sources

### Priority for this project

| Priority | Source | V1? | Notes |
|----------|--------|-----|--------|
| 1 | **Billing gRPC-web** `GetGrokCreditsConfig` with CLI bearer | **Yes** | Validated with CLI token alone |
| 2 | ACP `x.ai/billing` over `grok agent stdio` | Future | Returns `-32601 Method not found` on 0.2.118 |
| 3 | Browser cookies on grok.com | **No** | Explicitly out of scope (no web auth) |
| 4 | Local session `signals.json` | **No** for quota | Context/token stats only; not subscription pool |

### Product semantics

Public documentation for SuperGrok-style subscriptions describes a **shared weekly usage pool** across Grok chat, Grok Build, and API-labeled usage. The menubar should treat the primary percent as that **credit / pool usage**, and label the window **Weekly** when `resetsAt - periodStart ≈ 7 days`.

---

## 3. Primary path: GetGrokCreditsConfig

### Endpoint

```http
POST https://grok.com/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig
```

### Request

- **Body:** empty protobuf message framed as gRPC-web:
  - 1 byte flags = `0x00` (data frame, uncompressed)
  - 4 bytes big-endian message length = `0`
  - 0 message bytes  
  → total body: `00 00 00 00 00`
- **Headers (recommended):**

| Header | Value |
|--------|--------|
| `Content-Type` | `application/grpc-web+proto` |
| `Accept` | `application/grpc-web+proto` (or `*/*`) |
| `x-grpc-web` | `1` |
| `Authorization` | `Bearer <auth.json key>` |
| `Origin` | `https://grok.com` |
| `Referer` | `https://grok.com/?_s=usage` |
| `User-Agent` | `SimpleUsageBar/<version>` (identifiable, polite) |

### Success response

- HTTP **200**
- `Content-Type: application/grpc-web+proto` (typical)
- Body: one or more gRPC-web frames:
  1. **Data frame** (`flags & 0x80 == 0`): protobuf payload
  2. **Trailer frame** (`flags & 0x80 != 0`): ASCII trailers, must include `grpc-status: 0`

### Error classification

| Signal | App handling |
|--------|----------------|
| HTTP 401 / 403 | Unauthenticated / reauth |
| gRPC status **16** (Unauthenticated) | Unauthenticated / reauth |
| gRPC status **7** with auth-like message | Unauthenticated / reauth |
| Team-specific rejection | `teamUnsupported` if `principal_type == Team` |
| HTTP 5xx / network | Error or stale |
| HTTP 200 but missing/invalid frames | Parse error |
| `grpc-status != 0` | `rpcFailed(status, message)` |

### Live probe (2026-08-02, personal User principal)

- CLI bearer accepted (**no browser cookies**).
- Approximate decoded values:
  - **Used percent:** ~43%
  - **Period start:** `2026-07-27 01:01:01 UTC`
  - **Period end:** `2026-08-03 01:01:01 UTC` (7-day window)

Do **not** commit real tokens or full live responses containing account-identifying data without redaction.

---

## 4. Protobuf layout (reverse-engineered)

Field numbers below are **observed**, not from an official `.proto` file. Use them as a starting map; write the parser to tolerate missing fields and unknown fields.

### Outer gRPC-web message body

Typically a single length-delimited field wrapping the credits config:

```text
message GetGrokCreditsConfigResponse {
  // field 1: CreditsConfig (message)
  CreditsConfig config = 1;
}
```

### Nested `CreditsConfig` (observed)

| Field | Wire type | Observed meaning |
|-------|-----------|------------------|
| 1 | fixed32 (float) | **Primary credit usage percent** (e.g. `43.0`) |
| 2 | bytes/message | Often empty |
| 3 | bytes/message | Often empty |
| 4 | message (Timestamp) | **Period start** (`seconds`, `nanos`) |
| 5 | message (Timestamp) | **Period end / reset** (`seconds`, `nanos`) |
| 7 | repeated message | Additional buckets: `type` (varint) + optional percent float |
| 8 | message | Current period block (type + start/end timestamps) |
| 11 | varint | Flag / enum (observed `1`) |
| 12 | bytes | Often empty |
| 13 | varint | Flag / enum (observed `1`) |

### Timestamp submessage (protobuf well-known style)

```text
message Timestamp {
  int64 seconds = 1;  // Unix seconds
  int32 nanos   = 2;
}
```

### Mapping to `UsageSnapshot`

| Snapshot field | Source |
|----------------|--------|
| `usedPercent` | Config field **1** float; if omitted in a valid current period, treat as **0** |
| `resetsAt` | Config field **5** → `Date(timeIntervalSince1970: seconds)` |
| `periodStart` | Config field **4** |
| `windowLabel` | If `resetsAt - periodStart` in `[6d, 8d]` → `.weekly`; in `[28d, 32d]` → `.monthly`; else `.credits` |
| `source` | `.billingApi` |
| `accountEmail` / `principalType` | From auth file, not protobuf |

### Parser implementation notes

1. Prefer a **small hand-written protobuf walker** (varint, len-delimited, fixed32/64) over shipping a full protoc stack for one message.
2. Ignore unknown fields.
3. Accept both framed gRPC-web and (if ever seen) raw protobuf bodies.
4. Unit-test against **binary fixtures** checked into `SimpleUsageBarTests/Fixtures/`.
5. If field 1 is absent but period timestamps exist, use **0%** (zero usage), not a hard failure — matches observed “omitted means zero” behavior in sibling tools.
6. Secondary field-7 buckets are **not** shown in v1 UI. They are a **plausible** per-product / per-surface breakdown (e.g. Build vs Chat vs Imagine) matching the grok.com Usage UI shape, but type ids are reverse-engineered only — do not surface until mapped.

---

## 5. Future path: ACP `x.ai/billing`

### Transport

```bash
grok agent stdio
```

- Line-delimited JSON-RPC 2.0 on stdin/stdout (no Content-Length framing).
- After `initialize`, call method `x.ai/billing` with empty/params `{}`.

### Status (0.2.118)

```json
{"jsonrpc":"2.0","id":2,"error":{"code":-32601,"message":"Method not found"}}
```

Billing appears wired for interactive TUI in some historical notes, not agent-stdio. **Do not depend on this for v1.** When it starts returning data, prefer it only if it is more stable or richer than the HTTP path; design `GrokProvider` to try paths in a clear order.

### Expected result shape (from public tooling docs; may differ)

Monetary values as `{ "val": <cents> }`:

```json
{
  "billingCycle": {
    "billingPeriodStart": "2026-05-01T00:00:00Z",
    "billingPeriodEnd": "2026-06-01T00:00:00Z"
  },
  "monthlyLimit": { "val": 99900 },
  "usage": {
    "includedUsed": { "val": 12345 },
    "onDemandUsed": { "val": 0 },
    "totalUsed": { "val": 12345 }
  }
}
```

Derived: `usedPercent = totalUsed / monthlyLimit * 100`, `resetsAt = billingPeriodEnd`.

### Implementation hazards (if enabling later)

- Do not JSON-escape `/` as `\/` in method names if the CLI parser is strict (historical quirk).
- Kill the child process on timeout to avoid leaks.
- Timeouts: ~8s initialize, ~12s billing.

---

## 6. Local session signals (non-quota)

Path pattern:

```text
~/.grok/sessions/<url-encoded-cwd>/<session-id>/signals.json
```

Example fields: `contextTokensUsed`, `contextWindowTokens`, `modelsUsed`, `turnCount`. Useful for diagnostics or a future “local activity” line; **not** a substitute for subscription %.

---

## 7. Error & state matrix

| Condition | Provider throws / returns | UI state |
|-----------|---------------------------|----------|
| No auth file | `missingCredentials` | `unauthenticated` |
| All tokens expired | `expiredCredentials` | `unauthenticated` |
| Auth rejected by server | `authRejected` | `unauthenticated` |
| Team principal + unsupported surface | `teamUsageUnsupported` | `teamUnsupported` |
| Network failure + have last snapshot | surface error | `stale(snapshot, message)` |
| Network failure + no snapshot | `network` | `error` |
| Parse failure | `parseFailed` | `error` or `stale` |
| Success | `UsageSnapshot` | `ready` |

---

## 8. Security checklist for implementers

- [ ] Never write tokens to logs, Crashlytics, or test output.
- [ ] Redact fixtures (replace JWT with `test-token`).
- [ ] Use HTTPS only; no cleartext fallback.
- [ ] Do not upload auth.json anywhere.
- [ ] Min fetch interval 30s; default poll 5 minutes.
- [ ] Identifiable User-Agent for debugging abuse reports.

---

## 9. Validation checklist (manual)

1. `grok logout` → app shows unauthenticated.
2. `grok login` → Refresh → used % and reset appear.
3. Compare % roughly with grok.com Usage UI (same weekly pool).
4. Airplane mode → stale or error, no crash.
5. Corrupt `auth.json` → unauthenticated / error, no crash.

---

## 10. Revision history

| Date | Note |
|------|------|
| 2026-08-02 | Initial doc from design brainstorm; CLI bearer + GetGrokCreditsConfig validated; agent stdio billing Method not found on 0.2.118 |
