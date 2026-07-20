# RouterOS ACME Automation — LLM Knowledge Base

> **Purpose:** AI-agent grounding context for **RouterOS 7.23+** ACME automation development.
> **Format:** Token-optimized. No prose. Tables + code + constraints only.
> **Scope:** The ACME subsystem was **refactored starting in 7.22 and stabilized in 7.23**.
> This file documents the **7.23.2 stable** behavior (chosen deliberately as the mature
> target). **Do NOT extrapolate 7.21 behavior** — log strings, retry logic, and the fire
> model all changed. See §Version Scope.
> **Confirmation legend:** `[Pebble]` = Pebble 2.10.1 lab. `[LE-stg]` = also confirmed
> against real Let's Encrypt **staging**. Unmarked platform facts are CHR 7.23.2 stable.
> LE **production** behavior was **not** exercised — do not assume it.

---

## 🗓️ Version Scope & Refactor

```
FACT: RouterOS ACME had a MAJOR refactor beginning in 7.22, stabilized in 7.23.
FACT: 7.23.2 stable is the reference target here (mature; chosen on purpose).
FACT: 7.21 behavior is NOT a valid basis for 7.23 — do not carry it over.
FACT: Daemon log strings are NOT guaranteed stable across point releases.
```

| Aspect                | 7.21 (legacy)            | 7.23.2 (this doc)                          |
| --------------------- | ------------------------ | ------------------------------------------ |
| Log topic             | (varied)                 | **`certificate`** (`certificate,info/error`) |
| `topics=acme-client`  | —                        | **Does not exist**                         |
| Fire model            | "~60 days before expiry" | `invalid-after − lifetime/5` (80% of life) |
| Provisioning verb     | `enable-ssl-certificate` | **`add-acme`** (async)                      |

**⚠️ RE-CAPTURE THE VOCABULARY ON EVERY UPGRADE.** String stability is not guaranteed:
between **7.23rc2 → 7.23.1** the daemon renamed a CSR transient from
`generating ssl certificate signing request` → `generating acme certificate signing request`.
Any automation that treats an unknown `acme-status` string as terminal will break on such a
rename. Anchor on stable substrings (see §Daemon Log Vocabulary), never on full transient text.

---

## 🔑 Core Behavioral Facts

| Fact                          | Value                                        | Source      |
| ----------------------------- | -------------------------------------------- | ----------- |
| Default cert validity         | 90 days (→45 days by 2028)                   | LE Policy   |
| Auth cache (2025-2026)        | **30 days**                                  | Boulder/LE  |
| Auth cache (Feb 2027)         | **10 days**                                  | LE Profiles |
| Auth cache (Feb 2028)         | **7 hours**                                  | LE Profiles |
| Renewal fire point            | **`invalid-after − lifetime/5`** (80% of life) | Empirical `[LE-stg]` |
| Fire jitter                   | **+~14 s** after the scheduled instant       | Empirical `[Pebble]` |
| Log topic                     | **`certificate`** (info + error sub-topics)  | Empirical   |
| Provisioning command          | **`/certificate add-acme …`** (asynchronous) | RouterOS    |
| Challenge type supported      | **HTTP-01 only** (native; no DNS-01, no ARI) | RouterOS    |

```
FACT: On a 90-day cert the fire point is invalid-after − 18 days (90/5 = 18). [LE-stg]
FACT: add-acme returns immediately; issuance completes out-of-band seconds later.
```

---

## 🔬 Daemon Log Vocabulary (7.23.2)

The ACME daemon logs under the **`certificate`** topic — `certificate,info` and
`certificate,error`. Strings below are the verbatim `$message` shape (CN / `0x<ID>` /
timestamp abstracted). These are the load-bearing signals for any log-driven automation.

### Info lines (`certificate,info`)

| Signal              | Verbatim `$message`                                                          | Meaning                                            |
| ------------------- | --------------------------------------------------------------------------- | -------------------------------------------------- |
| Create              | `new acme cert '<CN>' (0x<ID>) created`                                      | issuance/renewal started; informational            |
| Fresh import ✅     | `acme cert '<CN>' (0x<ID>) imported, next update scheduled at <ISO8601Z>`    | first-issuance success; ts = **ISO-8601 Zulu**     |
| Renewal ✅          | `cert '<CN>' (0x<ID>) updated, next update scheduled at <DOTTED-UTC>`        | renewal success; ts = **dotted UTC, no zone**      |
| Retry-schedule ⚠️   | `next acme cert '<CN>' (0x<ID>) update scheduled at <DOTTED-UTC>`            | emitted after **every error** AND after scheduling — **NOT a success line** |

### Error lines (`certificate,error`)

All share prefix `acme cert 'acme client <CN>' (0x<ID>) error: …`. Verbatim tails:

| Cause class          | Tail after `error: `                                                                                                   |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Port closed (RST)    | `http-01 challenge validation failed, urn:…:connection - Get "http://<CN>:80/.well-known/acme-challenge/<N>": dial tcp <IP>:80: connect: connection refused` |
| Port DROP (timeout)  | `…challenge validation failed, urn:…:connection - … context deadline exceeded (Client.Timeout exceeded while awaiting headers)` |
| No route             | `…challenge validation failed, urn:…:connection - … dial tcp <IP>:80: connect: no route to host`                      |
| DNS failure          | `…challenge validation failed, urn:…:connection - … dial tcp: lookup <host> on <resolver>:53: no such host`           |
| Bad nonce            | `JWS has an invalid anti-replay nonce: <b64> (urn:ietf:params:acme:error:badNonce, status:400)`                        |
| Retries exhausted    | `unable to retrieve acme certificate - number of retries exhausted`                                                     |
| Policy reject (term) | `Order included an identifier for which issuance is forbidden by policy: "<CN>" (…:rejectedIdentifier, status:400)`     |
| Directory down (A)   | `http client error, please make sure device is connected to internet and acme server is reachable`                     |
| Directory down (B)   | `acme update failed - network error` (co-logged with A)                                                                 |
| Fresh token race     | `Non-200 status code … returned 404` (concurrent fresh orders raced the HTTP-01 token fetch)                            |

### Vocabulary rules (critical for parsers)

```
FACT: The ONLY stable phrase across all reachability failures is:
        challenge validation failed
      The connection-cause TAIL varies (connection refused / context deadline
      exceeded / no route to host / no such host). Anchor on the prefix, NOT the tail —
      a real CA emits yet another timeout wording.

FACT: TWO timestamp formats on one cert in one session:
        fresh import           → ISO-8601 Zulu   2026-07-17T22:20:06Z
        renewal + retry-sched  → dotted UTC-local 2026.07.17-23:36:56  (no zone marker)
      A regex anchored on "[0-9]{4}-…T" silently misses every renewal/retry line.

FACT: TWO name surfaces. info → '<CN>' bare. error → 'acme client <CN>'.
      Robust: take first single-quoted field, strip a leading "acme client " if present.

FACT: (0x<ID>) is the RouterOS internal cert id, NOT the X.509 serial.
      It is CONSTANT across renewals; the X.509 serial rotates each renewal.
      Use the CN as the per-cert key.
```

**`acme-status` is a separate, unreliable surface.** The `/certificate` `acme-status`
progress strings (`connecting to <dir>`, `generating private key` [fresh only],
`generating acme certificate signing request`, `requesting validation`,
`requesting authorization`, `requesting order finalization`, `requesting certificate`,
`requesting new nonce`, terminal `next update at <ts>`) are open-ended and
sampling-dependent — states are skipped faster than 200 ms polling and new ones appear
under load. **Never build a transient allow-list off `acme-status`.** Classify from the
`/log` `certificate` topic instead.

---

## 🔁 Fire-Timing & Renewal Model

```
FACT: schedule_instant = invalid-after − (lifetime / 5)   # renew at 80% of lifetime
FACT: actual fire = schedule_instant + small jitter (observed +13.7…+14.6 s). [Pebble]
FACT: 90-day cert → fires at invalid-after − 18 days. [LE-stg]
FACT: authorization poll interval within one order is ~10 s fixed. [Pebble]
FACT: bootstrap span create→import ≈ 34–44 s [Pebble]; 42 s over real LE-staging. [LE-stg]
```

**Fresh-vs-renewal retry asymmetry (load-bearing):**

| Path                                | Retry behavior on failure                                                            |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| **Fresh `add-acme`** (no live order) | **Single-shot. NO auto-retry on ANY failure** — post-order validation fail AND pre-order directory-unreachable both = one attempt then silence (silent across 800 s+). |
| **Scheduled renewal** (order live)  | **Daemon self-retries.** Reachability fails retry **~27–31 s**; directory-down retries **~15 s**; recovers to a success line with no new `add-acme`. |

```
FACT: The rumored "7.23rc2 15–30 s pre-order retry branch" does NOT exist on 7.23.2.
      A fresh order that fails stays failed until operator action.
```

`add-acme` parameter signature: `domain-names=` (plural), `name=`, `directory-url=`,
`eab-kid=`, `eab-key-b64=`.

---

## 🩹 Failure & Recovery Semantics

```
FACT: Reachability classes SELF-HEAL on a live renewal order. connection refused (RST),
      context deadline exceeded (DROP-timeout), no route to host, and DNS no such host all
      recover on the daemon's own next retry once the path is fixed — the order stays live.
      DROP-timeout heal confirmed ×3. [Pebble]

FACT: "number of retries exhausted" is NOT terminal on a LIVE renewal order.
      The daemon keeps retrying the same live order PAST its own "retries exhausted" line
      and can heal to "updated, next update" unaided once a transient (e.g. badNonce) clears
      (E9 at t+30 s, then 2 further successes over 300 s with the X.509 serial rotating).
      Terminality applies ONLY to a fresh pre-order, never to a live renewal. [Pebble]

FACT: Directory-down is also fresh-vs-live split: terminal (single-shot) on a fresh
      pre-order; retryable ~15 s on a live renewal order. [Pebble]

FACT: Some mid-order abandonment ends TRULY terminal (E a flags on the cert, empty serial).
      When an order dies terminally, NO success /log event will ever follow. [Pebble]
```

**Placeholder / not-yet-issued state** — a freshly-added cert can expose, at ~t+1 s:
`serial-number = ""` and `invalid-after = 1970-01-01 00:00:00` (epoch sentinel). A naive
`serial != ""` "is-it-live?" check false-positives here. Trust only the
`imported, next update` event, or an `invalid-after` whose year ≠ 1970 with a serial that
survives a re-read.

```
FACT: NEVER issue fresh add-acme concurrently. 4 fresh add-acme ~5 ms apart against one
      backend raced the HTTP-01 token fetch → "Non-200 status code … returned 404" and one
      order stranded PERMANENTLY. Serialize fresh issuance. [Pebble]
```

**Removal & stuck orders:**

```
FACT: /certificate remove is BLOCKED for a cert's whole active acme lifetime:
        "cannot remove certificate while acme update is in progress"
      During generation it may instead block with:
        "certificate generation is in progress"

FACT: A stuck order ("retries exhausted") can be PERMANENTLY un-removable by bounded retry
      (still blocked after 800 s+ of retries and 20 min+ of confirmed daemon idle). [Pebble]

FACT: A stuck ACME order SURVIVES /system reboot — the daemon RESUMES it post-boot
      (reaches acme-status "requesting authorization" within ~60 s of boot); removal stays
      blocked. REBOOT IS NOT A RESET. To clear: make :80 reachable, let the resumed order
      reach "next update at …", then remove in the idle gap (heal-then-remove). [Pebble]

FACT: A live order interrupted by reboot re-fires on its next post-boot retry
      (re-emits the same challenge-validation-failed class); the daemon does not drop it. [Pebble]
```

---

## ⏰ Clock & Time

```
FACT: Renewal fire times are WALL-CLOCK-anchored (invalid-after − lifetime/5).
      Monotonic/uptime timers are immune to NTP loss; wall-clock scheduling is not.

FACT: A FORWARD wall-clock jump across one or more fire thresholds triggers renewal(s)
      IMMEDIATELY — the classic "runaway renewal storm" when NTP is lost then restored with
      a large forward correction, potentially firing multiple certs at once. [Pebble]

FACT: Real NTP loss during a live renewal does NOT stop the daemon retrying the live order
      (retry cadence is not wall-clock-gated in the observed window). [Pebble]
```

Consequence: any automation must **bound concurrent renewal fan-out** to stay clear of the
CA's failed-auth budget (§Constraints).

**Testing technique (jump the clock to trigger a scheduled renewal):**

```routeros
/system clock set date=2026-03-06 time=12:14:00
/log print follow where topics~"certificate"
```

---

## 🔌 Auth Cache & Firewall

Still valid on 7.23.2 (re-verified). Cached authorization = **no inbound :80 needed**.

```
FACT: Renewals within the auth-cache window require NO incoming validator traffic.
FACT: Firewall (filter/raw) shows 0 packets during a cached renewal — server-side auth
      reuse, NOT an internal bypass. Works even if :80 is strictly BLOCKED.
```

| Scenario                    | Port 80 required | Firewall matters |
| --------------------------- | ---------------- | ---------------- |
| Initial provisioning        | ✅ Yes           | ✅ Yes           |
| Renewal (cached auth <30 d) | ❌ No            | ❌ No            |
| Renewal (fresh auth >30 d)  | ✅ Yes           | ✅ Yes           |

**Fresh-vs-cached discriminator** `[LE-stg]`: during the validation window a **fresh**
validation shows **nonzero tcp/80 inbound** (measured 5 dstnat pkts / 300 B + 26
filter-input pkts / 2807 B); a **cache reuse** shows **zero**. Nonzero :80 during the window
= fresh validation. (LE staging's ~30-day cache "hides" the fresh path — don't rely on
staging to exercise validation repeatedly.)

### WWW Service vs ACME-Plain

| Config                    | Initial provisioning | Renewal (cached) |
| ------------------------- | -------------------- | ---------------- |
| `www=yes, acme-plain=yes` | ✅ Works             | ✅ Works         |
| `www=no,  acme-plain=yes` | ❌ Fails             | ✅ Works         |
| `www=yes, acme-plain=no`  | ✅ Works             | ✅ Works         |

**CONSTRAINT:** initial provisioning requires the `www` service reachable on :80.

### Offline-Router Risk (cache miss)

If a router is offline **> cache window** (30 d now; 7 h in 2028) the cached authorization
expires; the next renewal **fails** if :80 is firewalled. Keeping :80 always-open is
insecure; calendar-based opening is unreliable (clock drift). A reactive `do/on-error`
wrapper that only opens :80 when a cached renewal fails is the safer shape — but note the
daemon self-retries a **live** order (§Failure), so distinguish "no live order" from
"live order retrying."

---

## 🔎 Certificate Properties (Scripting)

```routeros
# Use print as-value, NOT /certificate get in loops
:local certs [/certificate print as-value where common-name~"domain"]
:foreach c in=$certs do={
    :put ("Serial: " . ($c->"serial-number"))   # rotates every renewal
    :put ("Issuer: " . ($c->"issuer"))           # (STAGING) marker distinguishes env
    :put ("Expires: " . ($c->"invalid-after"))
    :put ("AKID: " . ($c->"akid"))
    :put ("Fingerprint: " . ($c->"fingerprint"))
}
```

| Property        | Use case                                          |
| --------------- | ------------------------------------------------- |
| `common-name`   | **Stable per-cert key** (name persists across renewals) |
| `serial-number` | Detect renewal (**X.509 serial changes**; ≠ `0x<ID>` log id) |
| `issuer`        | Staging vs Production (`(STAGING)` marker)         |
| `invalid-after` | Expiry; also the fire-model anchor                |
| `akid`          | Authority Key ID (issuer chain)                   |
| `fingerprint`   | Unique cert identity                              |

```
FACT: Certificate NAME persists across renewals; SERIAL changes.
FACT: Service bindings (IPsec, SSTP, OVPN) auto-update to new cert content — no manual rebind.
FACT: reset-private-key=yes is RE-PROVISIONING, not rotation — it creates a NEW cert object
      (new name/id), orphaning services bound to the old one, and forces a fresh HTTP-01 cycle
      (fails on closed :80 even with cached auth). Update service bindings manually after.
FACT: ACME directory URL is stored with the cert; environment (staging/prod) persists across
      reboot and renewal. To switch env, delete the cert and re-provision.
```

Example staging issuer: `CN=(STAGING) Riddling Rhubarb R12`.

---

## 📋 Command Reference

### Provision (staging)

```routeros
/certificate add-acme name=my-cert \
    domain-names=host.example.com \
    directory-url="https://acme-staging-v02.api.letsencrypt.org/directory"
```

### Provision (production)

```routeros
/certificate add-acme name=my-cert \
    domain-names=host.example.com \
    directory-url="https://acme-v02.api.letsencrypt.org/directory"
```

### Watch ACME activity (7.23.2 topic + strings)

```routeros
/log print follow where topics~"certificate"
# success (fresh):  imported, next update scheduled at
# success (renew):  updated, next update scheduled at
# reachability fail: challenge validation failed        (anchor on this substring)
# retry-schedule:    next acme cert … update scheduled at   (NOT a success)
```

---

## ⚠️ Constraints & Gotchas

### Rate limits (Let's Encrypt)

| Limit                   | Value                                                        |
| ----------------------- | ----------------------------------------------------------- |
| Failed validations      | **5 / hour / account / identifier** — verbatim CA message:  `too many failed authorizations (5) … in the last 1h` |
| Duplicate certificates  | 5 / week (same hostname set)                                |
| Certificates per domain | 50 / week                                                   |

A window that closes mid-renewal and produces 5 http-01 timeouts trips the failed-auth
budget → 429 storm. Bound retries and fan-out accordingly.

### RouterOS limitations

- **No DNS-01** (native) — HTTP-01 only.
- **No ARI** (ACME Renewal Information) — not implemented.
- **`add-acme` is asynchronous** but issuance itself is blocking server-side; some other
  `/certificate` operations block the shell.
- **No auth-deactivation API** — cannot force a fresh challenge from UI/scripting.

### ACME-relevant scripting traps (see `references/anti-patterns.rsc` for the full catalogue)

- `!~` (negated regex) lints clean but **throws `cannot invert string`** at runtime — use
  `!($v ~ $pat)`.
- A local named `name` **shadows** the object property in `where name=$name` filters — use
  unambiguous locals (`certName`).
- A script that removes its own job/object aborts with **`interrupted`** (removal still
  completes first — audit independently).
- `/system logging` `regex=` is **hard-capped at 63 bytes** (64 → `Invalid regex!`).
- A `target=script` logging action **carries a dead runtime binding across reboot** —
  matching lines still land in `/log` but the script never fires until the action **and**
  its referencing rule are recreated (action first, then rule).

### Anti-patterns (LLM traps)

| ❌ Don't assume                        | ✅ Correct                                              |
| -------------------------------------- | ------------------------------------------------------ |
| `topics=acme-client` exists            | Topic is **`certificate`** (`certificate,info/error`)  |
| Every renewal needs :80                | Only if the auth cache expired                          |
| Firewall blocks all renewals           | Cached-auth renewal ignores the firewall                |
| `acme-plain` alone works for initial   | Initial needs the `www` service reachable               |
| "retries exhausted" = dead cert        | NOT terminal on a **live** renewal — daemon self-heals  |
| Reboot clears a stuck order            | Daemon **resumes** it post-boot — heal-then-remove      |
| One log line = one script run          | Bursts coalesce; consumers must be **idempotent**       |
| Anchor parsers on the error tail       | Anchor on **`challenge validation failed`**             |
| One timestamp format                   | ISO-Zulu (import) **vs** dotted-UTC (renew/retry)       |

---

## 🧪 Evidence & Methodology

### Test environment

| Component    | Value                                                       |
| ------------ | ----------------------------------------------------------- |
| RouterOS     | **v7.23.2 stable (CHR)** — deliberate mature target         |
| ACME servers | **Pebble 2.10.1** (cache-free lab) + **Let's Encrypt staging** |
| Time control | System-clock manipulation (`/system clock set`)             |
| Monitoring   | `/log print follow where topics~"certificate"`; on-router sub-second polling |

### Confirmation split (honesty)

- **`[LE-stg]` confirmed against real Let's Encrypt staging:** bootstrap span 42 s over the
  real public path; the 7.23.2 event vocabulary is produced identically on the happy path
  (`created` → `imported, next update scheduled at <ISO8601Z>`); fire model holds on a real
  90-day cert (`invalid-after − 18 d`); real validator traffic transited :80 during the
  window (fresh validation, not cache reuse).
- **`[Pebble]`-only (not yet vs real LE):** open-on-failure heal leg; live-order retry
  cadence against LE; real LE outage / 4xx/5xx / **429** vocabulary; natural log-event-driven
  renewal against LE.
- **LE production: never exercised** — real 429-by-source-IP and multi-vantage validation
  are unverified. Do not assume.

### Experiment archetypes (reproducible)

- **Matrix:** `www` × `acme-plain` × firewall (2×2×2), fresh cert per config, record success/fail.
- **Microscope:** 1 s on-router polling around the scheduled instant → measure fire jitter.
- **Zoom-in:** provision → bind IPsec/SSTP → reboot → renew → verify bindings persist.
- **No-NAT:** disable upstream DST-NAT → trigger renewal → observe 0 packets + success (proves cached-auth reuse).

---

## 📚 References

| Resource                   | URL                                                                 |
| -------------------------- | ------------------------------------------------------------------- |
| LE Profiles (auth windows) | https://letsencrypt.org/docs/profiles/                              |
| LE 45-day timeline         | https://letsencrypt.org/2025/12/02/from-90-to-45                    |
| LE rate limits             | https://letsencrypt.org/docs/rate-limits/                           |
| RFC 8555 (ACME)            | https://datatracker.ietf.org/doc/html/rfc8555                       |
| Boulder source (RA)        | https://github.com/letsencrypt/boulder/blob/main/ra/ra.go           |
| DNS-PERSIST-01 draft       | https://www.ietf.org/archive/id/draft-ietf-acme-dns-persist-00.html |

---

> **Keywords:** _RouterOS 7.23, 7.22 ACME refactor, add-acme, Let's Encrypt, HTTP-01,
> certificate log topic, daemon log vocabulary, challenge validation failed, fire model
> invalid-after lifetime/5, authorization reuse, auth cache, renewal self-heal, retries
> exhausted not terminal, cannot remove certificate while acme update is in progress,
> runaway renewal storm, rate limits, acme-plain, DNS-01, LLM grounding, AI agent context_
