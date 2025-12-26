# RouterOS ACME Automation — LLM Knowledge Base

> **Purpose:** AI-agent grounding context for RouterOS 7.21+ ACME automation development.  
> **Format:** Token-optimized. No prose. Tables + code + constraints only.

---

## 🔑 Core Behavioral Facts

| Fact                          | Value                       | Source      |
| ----------------------------- | --------------------------- | ----------- |
| Default cert validity         | 90 days (→45 days by 2028)  | LE Policy   |
| Auth cache (2025)             | **30 days**                 | Boulder/LE  |
| Auth cache (Feb 2027)         | **10 days**                 | LE Profiles |
| Auth cache (Feb 2028)         | **7 hours**                 | LE Profiles |
| RouterOS auto-renewal trigger | ~60 days before expiry      | Empirical   |
| Renewal trigger delay         | 18-70s after scheduled time | Empirical   |
| Challenge type supported      | HTTP-01 only (native)       | RouterOS    |

---

## 🔬 Empirical Discoveries (Dec 2025)

### Authorization Reuse (Critical)

```
FACT: Renewals within auth cache window require NO incoming traffic.
FACT: Firewall rules (filter/raw) show 0 packets during cached renewal.

FACT: This is NOT an internal bypass — it's server-side auth reuse.
FACT: Cached Auth renewal works even if Port 80 is strictly BLOCKED (timeout) at the firewall.
```

| Scenario                   | Port 80 Required | Firewall Matters |
| -------------------------- | ---------------- | ---------------- |
| Initial provisioning       | ✅ Yes           | ✅ Yes           |
| Renewal (cached auth <30d) | ❌ No            | ❌ No            |
| Renewal (fresh auth >30d)  | ✅ Yes           | ✅ Yes           |

### WWW Service vs ACME-Plain

| Config                    | Initial Provisioning | Renewal (Cached) |
| ------------------------- | -------------------- | ---------------- |
| `www=yes, acme-plain=yes` | ✅ Works             | ✅ Works         |
| `www=no, acme-plain=yes`  | ❌ Fails             | ✅ Works         |
| `www=yes, acme-plain=no`  | ✅ Works             | ✅ Works         |

**CONSTRAINT:** Initial provisioning requires `www` service enabled.

### In-Place Certificate Swap

```
FACT: Certificate NAME persists across renewals.
FACT: Certificate SERIAL changes.
FACT: Service bindings (IPsec, SSTP) auto-update to new cert content.
FACT: No manual rebinding required.
```

### 3. Key Rotation & Auth Cache (The "Reset" Risk)

**Experiment:** `/certificate/enable-ssl-certificate ... reset-private-key=yes`
**Result:**

- **FAILURE** if Port 80 is closed, even if auth was cached for the domain.
- **Reason:** Reseting the key likely generates a new ACME Account Key. New accounts cannot access the Authorization Cache of the old account.
- **Impact:** Key rotation **forces** a fresh HTTP-01 validation cycle.
- **Constraint:** Do not rotate keys if you are relying on cached authorization (closed ports).
- **Persistence (FAILURE):** A failed renewal attempt **does not damage** the existing certificate (Safe).
- **Persistence (SUCCESS):** A successful rotation **CREATES A NEW CERTIFICATE OBJECT** (New Name, New ID).
  - **CRITICAL:** The old certificate remains. The new one is added.
  - **IMPACT:** Services (SSTP, OVPN, IPsec etc.) bound to the old certificate **WILL NOT** switch to the new one. They become orphaned.
  - **Constraint:** `reset-private-key=yes` is NOT a rotation tool, it is a **Re-provisioning** tool. You must update all services to point to the new certificate manually or via script.

### 4. The "Offline Router" Risk (Cache Miss Recovery)

**Scenario:**
If a router is offline for >30 days (or >7 hours in 2028), the cached authorization **expires**.
When it comes back online, the standard renewal attempt will **FAIL** if the firewall blocks Port 80.

**Naive Fix:** Always keep Port 80 open (Insecure).
**Targeted Fix:** Open Port 80 based on calendar (Unreliable due to clock drift).

**Smarter Strategy (Reactive Renewal):**
Use a script to attempt renewal and _dynamically_ open the firewall only if the safe/cached renewal fails.

```routeros
# Reactive Renewal Logic
do {
   # Try renewal (expecting cached auth success)
   /certificate/enable-ssl-certificate ...
} on-error={
   # If failed (likely auth expired), open firewall temporarily
   /ip firewall filter disable [find comment="ACME_DROP"]
   /ip service set www disabled=no

   # Retry renewal
   /certificate/enable-ssl-certificate ...

   # Re-secure
   /ip firewall filter enable [find comment="ACME_DROP"]
   /ip service set www disabled=yes
}
```

**Recommendation:** Do not rely solely on the native scheduler if your devices might be offline for extended periods. Use a `do/on-error` wrapper script that handles the "auth expired" edge case intelligently.

---

### Environment Persistence (Staging vs Production)

```
FACT: ACME directory URL is stored with the certificate.
FACT: Environment persists across reboots and renewals.
FACT: Staging cert renewals stay in Staging (no "leak" to Production).
FACT: To switch environments, must delete cert and re-provision.
```

### Scheduler Internals

| Behavior           | Value                            |
| ------------------ | -------------------------------- |
| Check interval     | ~15 minutes                      |
| Trigger precision  | 18-70s after scheduled time      |
| Backoff on failure | Short retry interval (logged)    |
| Schedule format    | ISO 8601: `YYYY-MM-DDTHH:MM:SSZ` |
| Backoff reset      | On router reboot                 |

### Certificate Properties (Scripting)

```routeros
# Get cert details (use print as-value, NOT /certificate get in loops)
:local certs [/certificate print as-value where common-name~"domain"]
:foreach c in=$certs do={
    :put ("Serial: " . ($c->"serial-number"))
    :put ("Issuer: " . ($c->"issuer"))
    :put ("Expires: " . ($c->"invalid-after"))
    :put ("AKID: " . ($c->"akid"))
    :put ("Fingerprint: " . ($c->"fingerprint"))
}
```

**Key properties for verification:**
| Property | Use Case |
|----------|----------|
| `serial-number` | Detect renewal (changes) |
| `issuer` | Verify Staging vs Production |
| `invalid-after` | Expiry date |
| `akid` | Authority Key ID (issuer chain) |
| `fingerprint` | Unique cert identity |

### Time Manipulation (Testing Technique)

```routeros
# Jump system clock to trigger renewal
/system clock set date=mar/06/2026 time=12:14:00

# Monitor logs for trigger
/log print follow where topics~"acme"
```

**CONSTRAINT:** RouterOS scheduler uses system clock. Time jump triggers scheduled events.

### Issuer Identification (Staging vs Production)

| Environment    | Issuer Contains              |
| -------------- | ---------------------------- |
| **Staging**    | `(STAGING)` in issuer string |
| **Production** | No `(STAGING)` prefix        |

Example Staging issuer: `CN=(STAGING) Riddling Rhubarb R12`

---

## 📋 RouterOS Command Reference

### Provisioning (Staging)

```routeros
/certificate/enable-ssl-certificate \
    directory-url="https://acme-staging-v02.api.letsencrypt.org/directory" \
    dns-name=your-domain.com
```

### Provisioning (Production)

```routeros
/certificate/enable-ssl-certificate \
    directory-url="https://acme-v02.api.letsencrypt.org/directory" \
    dns-name=your-domain.com
```

### Check Renewal Schedule

```routeros
/log print where topics~"acme" and message~"scheduled"
```

### Log Patterns

| Event            | Message Pattern                                 |
| ---------------- | ----------------------------------------------- |
| Schedule created | `cert update scheduled at YYYY-MM-DDTHH:MM:SSZ` |
| Renewal success  | `ssl certificate updated`                       |
| Renewal failure  | `failed to update ssl certificate`              |
| Next schedule    | `next cert update scheduled @ ...`              |

---

## ⚠️ Constraints & Gotchas

### Rate Limits (Let's Encrypt)

| Limit                   | Value                   |
| ----------------------- | ----------------------- |
| Duplicate Certificates  | 5/week (same hostnames) |
| Certificates per Domain | 50/week                 |
| Failed Validations      | 5/hour/account/hostname |

### RouterOS Limitations

- **No DNS-01 support** — HTTP-01 only (native).
- **No auth deactivation API** — Cannot force fresh challenge from UI.
- **Blocking command** — `/certificate/enable-ssl-certificate` blocks shell.
- **No ARI support** — ACME Renewal Information not implemented.

### Anti-Patterns (LLM Traps)

| ❌ Don't Assume                      | ✅ Correct                        |
| ------------------------------------ | --------------------------------- |
| Firewall blocks renewals             | Only blocks if auth cache expired |
| `acme-plain` alone works for initial | Needs `www` service for initial   |
| Each renewal needs port 80           | Only if auth cache expired        |
| Can deactivate auth from RouterOS    | Not exposed in UI/scripting       |

---

## 🚀 Strategic Recommendations

### Cache Refresh Strategy (Port 80 Closed)

**Concept:** Renew frequently enough to stay within auth cache window.

| Timeframe | Auth Window | Suggested Interval | Viable   |
| --------- | ----------- | ------------------ | -------- |
| 2025-2026 | 30 days     | Every 20 days      | ✅ Yes   |
| 2027      | 10 days     | Every 7-8 days     | ⚠️ Risky |
| 2028+     | 7 hours     | N/A                | ❌ No    |

**Implementation:**

```routeros
/system scheduler add name="acme-cache-refresh" interval=20d on-event={
    :log info "ACME Cache Refresh triggered"
    /certificate/enable-ssl-certificate \
        directory-url="https://acme-v02.api.letsencrypt.org/directory" \
        dns-name=your-domain.com
}
```

### Long-Term Migration Path

| Phase          | Strategy                                    |
| -------------- | ------------------------------------------- |
| **Now (2025)** | Native RouterOS + cache refresh (20d)       |
| **2026**       | Evaluate DNS-PERSIST-01 (LE new feature)    |
| **2027+**      | External ACME client + DNS-01 + cert import |

### External ACME Pattern

```bash
# On Linux server (cron)
acme.sh --issue --dns dns_cf -d domain.com
scp ~/.acme.sh/domain.com/fullchain.cer admin@router:/
ssh admin@router '/certificate import file-name=fullchain.cer passphrase=""'
```

---

## 📚 References

| Resource                   | URL                                                                 |
| -------------------------- | ------------------------------------------------------------------- |
| LE Profiles (Auth Windows) | https://letsencrypt.org/docs/profiles/                              |
| LE 45-Day Timeline         | https://letsencrypt.org/2025/12/02/from-90-to-45                    |
| LE Rate Limits             | https://letsencrypt.org/docs/rate-limits/                           |
| RFC 8555 (ACME)            | https://datatracker.ietf.org/doc/html/rfc8555                       |
| Boulder Source (RA)        | https://github.com/letsencrypt/boulder/blob/main/ra/ra.go           |
| DNS-PERSIST-01 Draft       | https://www.ietf.org/archive/id/draft-ietf-acme-dns-persist-00.html |

---

## 🧪 Experiment Methodology (Reproducible)

### Matrix Experiment

**Purpose:** Test all combinations of `www`/`acme-plain`/firewall.
**Method:** 2x2x2 matrix, fresh cert each config, observe success/failure.

### Microscope Experiment

**Purpose:** High-precision timing of renewal trigger.
**Method:** 1s polling loop around scheduled time, log capture.

### Zoom-In Experiment

**Purpose:** Verify environment persistence and service binding durability.
**Method:** Provision → Bind to IPsec/SSTP → Reboot → Trigger renewal → Verify bindings.

### No-NAT Experiment

**Purpose:** Prove renewal works without any external traffic.
**Method:** Disable upstream DST-NAT → Trigger renewal → Observe 0 packets + success.
**Result:** Confirmed Authorization Reuse (server-side caching).

### Test Environment

| Component    | Value                                   |
| ------------ | --------------------------------------- |
| RouterOS     | v7.21rc3 (CHR)                          |
| ACME Server  | Let's Encrypt Staging                   |
| Time Control | System clock manipulation               |
| Monitoring   | `/log print follow where topics~"acme"` |

---

> **Keywords:** _RouterOS 7, ACME, Let's Encrypt, HTTP-01, Authorization Reuse, Certificate Renewal, Firewall Bypass, acme-plain, DNS-01, Rate Limits, LLM Grounding, AI Agent Context_
