# RouterOS SSH Private Key Import — LLM Knowledge Base

> **Purpose:** AI-agent grounding context for RouterOS 7.21+ SSH client authentication.
> **Format:** Token-optimized. No prose. Tables + code + constraints only.

---

## 🔑 Core Behavioral Facts

| Fact                     | Value                             | Source    |
| :----------------------- | :-------------------------------- | :-------- |
| **Supported Key Type**   | **RSA** only                      | Empirical |
| **Supported Format**     | **PEM** (PKCS#1/PKCS#8)           | Empirical |
| **Minimum Key Size**     | **2048 bits**                     | Empirical |
| **Maximum Key Size**     | **8192 bits** (Verified)          | Empirical |
| **Ed25519 Support**      | ❌ **UNSUPPORTED** (Import fails) | Empirical |
| **Passphrase Support**   | ✅ **YES** (via CLI parameter)    | Empirical |
| **Source File Behavior** | **Consumed** (Deleted on success) | Empirical |
| **Import Command**       | `/user ssh-keys private import`   | RouterOS  |

---

## 🔬 Empirical Discoveries (Jan 2026)

### Key Type Support Matrix

Tested on RouterOS 7.22beta5 (CHR).

| Algorithm | Size | Format  | Passphrase | Result      | Error Message                               |
| :-------- | :--- | :------ | :--------- | :---------- | :------------------------------------------ |
| RSA       | 1024 | PEM     | No         | ❌ **FAIL** | `keys smaller than 2048bit are not allowed` |
| RSA       | 2048 | PEM     | No         | ✅ **PASS** | -                                           |
| RSA       | 2048 | PEM     | Yes        | ✅ **PASS** | -                                           |
| RSA       | 8192 | PEM     | No         | ✅ **PASS** | -                                           |
| RSA       | 8192 | PEM     | Yes        | ✅ **PASS** | -                                           |
| Ed25519   | 256  | OpenSSH | Any        | ❌ **FAIL** | `unable to load key file (wrong format...)` |
| Ed25519   | 256  | PEM     | Any        | ❌ **FAIL** | `unable to load key file (wrong format...)` |

**CONSTRAINT:** Do NOT generate Ed25519 keys for RouterOS _private_ key imports. Use RSA 2048 or 4096.

### File Consumption Behavior

```
FACT: The source 'private-key-file' is DELETED immediately upon successful import.
FACT: A failed import (wrong password/format) preserves the file.
WARNING: Do not rely on the file persisting on the router after import.
```

### Passphrase Handling

```
FACT: Passphrases ARE supported in CLI via 'passphrase' parameter.
FACT: Parameter is NOT visible in default print/export (secure).
FACT: Wrong passphrase returns 'unable to load key file'.
```

---

## 📋 RouterOS Command Reference

### 1. Key Generation (Client-Side)

**CRITICAL:** Must use `-m PEM` to force legacy PEM format. Default OpenSSH format (RFC4716) is **NOT** compatible.

```bash
# Unencrypted RSA 4096 (Recommended Automation)
ssh-keygen -t rsa -b 4096 -m PEM -f id_rsa_router -N ""

# Encrypted RSA 4096 (Recommended Interactive)
ssh-keygen -t rsa -b 4096 -m PEM -f id_rsa_router_enc -N "StrongPass123!"
```

### 2. File Upload

```bash
scp id_rsa_router admin@192.168.88.1:id_rsa_router
```

### 3. Import Command (RouterOS)

```routeros
# Unencrypted Import
/user ssh-keys private import user=admin private-key-file=id_rsa_router

# Encrypted Import (Scripting)
/user ssh-keys private import user=admin private-key-file=id_rsa_router_enc passphrase="StrongPass123!"
```

### 4. Verification

```routeros
/user ssh-keys private print detail
# Flags: R - RSA
#  0 user=admin key-type=rsa bits=4096 info=""
```

### 5. Automation Patterns (Router-to-Router)

**User Context / Scoping (CRITICAL)**

```
FACT: Private keys are strictly scoped to the RouterOS User.
FACT: A script owned by 'admin' CANNOT use keys imported by 'api-ssh'.
CONSTRAINT: Scheduler scripts MUST have 'owner=api-ssh' to use that user's keys.
```

**Ownership Immutability (The "Sudo" Problem)**

```
FACT: Admin CANNOT change a scheduler's owner to another user (parameter missing/read-only).
FACT: Admin modifying a user's script changes the owner to 'admin' (Breaks execution chain).
WORKAROUND: To create a scheduler owned by 'api-ssh', you MUST log in AS 'api-ssh' (via SSH/API) and create it.
```

**Command Selection**
| Command | Use Case | Interactive? |
| :--- | :--- | :--- |
| `/system ssh` | Interactive Shell | ✅ Yes (Hangs scripts if auth fails) |
| `/system ssh-exec` | One-shot remote command | ❌ No (Best for automation) |

**Host Key Verification (TOFU)**

- RouterOS implements Trust-On-First-Use.
- **Problem**: First connection prompts `yes/no` to trust host key.
- **Impact**: Automation fails silently on fresh hosts.
- **Fix**: Must perform **manual first connection** or ensure known_hosts is populated.

---

## ⚠️ Constraints & Gotchas

### Anti-Patterns (LLM Traps)

| ❌ Don't Assume             | ✅ Correct                                                              |
| :-------------------------- | :---------------------------------------------------------------------- |
| Ed25519 is better/supported | **RSA 2048+ PEM** is the ONLY working option.                           |
| OpenSSH format works        | Must force **`-m PEM`** during generation.                              |
| RSA 1024 is enough          | Minimum size is **2048 bits**.                                          |
| File stays on disk          | File is **deleted** on success.                                         |
| `/tool/fetch` supports keys | NO. `/tool fetch` does NOT use these keys. These are for `/system/ssh`. |

### Scope of Usage

**These keys are for:**

- `/system ssh` (Router acting as client)
- `/system ssh-exec` (Router acting as client)

**These keys are NOT for:**

- `/tool fetch` (SFTP/SCP) — _Fetch does not currently support user-imported private keys for auth._
- User login TO the router (That's `/user ssh-keys import public-key-file=...`).

---

## 🧪 Experiment Methodology (Reproducible)

### Matrix Test

**Purpose:** Verify support for various algorithms and sizes.
**Method:**

1. Generate batch of keys (RSA 1k/2k/8k, Ed25519) with `ssh-keygen -m PEM`.
2. Upload all to CHR (7.22beta5).
3. Attempt import of each type.
4. Record error messages and success states.

### Persistence Test

**Purpose:** Confirm file cleanup.
**Method:**

1. List file (`/file print where name="key"`).
2. Run import.
3. List file again → Result: File gone.

### Passphrase Test

**Purpose:** Verify CLI argument support.
**Method:**

1. Generate key with password.
2. Import without `passphrase` param → Fail.
3. Import with wrong `passphrase` → Fail.
4. Import with correct `passphrase` → Success.

---

> **Keywords:** _RouterOS 7, SSH Client, Private Key Import, RSA PEM, Automation, User Keys, System SSH_
