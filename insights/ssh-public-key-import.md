# RouterOS SSH Public Key Import (User Auth) — LLM Knowledge Base

> **Purpose:** AI-agent grounding context for enabling SSH authentication TO the router (User Keys).
> **Format:** Token-optimized. No prose. Tables + code + constraints only.

---

## 🔑 Core Behavioral Facts

| Fact                      | Value                             | Source    |
| :------------------------ | :-------------------------------- | :-------- |
| **Supported Key Types**   | **RSA**, **Ed25519**              | Empirical |
| **Unsupported Key Types** | ECDSA (256/384/521), RSA < 2048   | Empirical |
| **Supported Format**      | OpenSSH (`.pub`), PKCS8 (PEM)     | Empirical |
| **Minimum RSA Size**      | **2048 bits**                     | Empirical |
| **Source File Behavior**  | **Consumed** (Deleted on success) | Empirical |
| **Deduping**              | **None** (Allows duplicate keys)  | Empirical |
| **Import Command**        | `/user ssh-keys import`           | RouterOS  |

> 🔥 **CRITICAL DISTINCTION:**
>
> - **Public Keys** (User login TO router): Supports **RSA** and **Ed25519**.
> - **Private Keys** (Router login OUT): Supports **RSA ONLY**.

---

## 🔬 Empirical Discoveries (Jan 2026)

### Key Type Support Matrix

Tested on RouterOS 7.22beta5 (CHR).

| Algorithm   | Size    | Format  | Result      | Error Message                               |
| :---------- | :------ | :------ | :---------- | :------------------------------------------ |
| **RSA**     | 1024    | OpenSSH | ❌ **FAIL** | `keys smaller than 2048bit are not allowed` |
| **RSA**     | 2048    | OpenSSH | ✅ **PASS** | -                                           |
| **RSA**     | 4096    | OpenSSH | ✅ **PASS** | -                                           |
| **RSA**     | 8192    | OpenSSH | ✅ **PASS** | -                                           |
| **Ed25519** | 256     | OpenSSH | ✅ **PASS** | -                                           |
| **ECDSA**   | 256     | OpenSSH | ❌ **FAIL** | `unable to load key file (wrong format...)` |
| **ECDSA**   | 384/521 | OpenSSH | ❌ **FAIL** | `unable to load key file (wrong format...)` |

### File Consumption & Edge Cases

```
FACT: The source 'public-key-file' is DELETED immediately upon successful import.
FACT: RouterOS does NOT dedup keys. Importing the same key twice results in TWO entries.
FACT: A user can have multiple keys (mixed types allowed, e.g., RSA + Ed25519).
```

---

## 📋 RouterOS Command Reference

### 1. Key Generation (Client-Side)

```bash
# RSA 4096 (Widely Compatible)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_router -C "your_user"

# Ed25519 (Modern & Fast - Supported for User Auth!)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_router -C "your_user"
```

### 2. File Upload

```bash
scp ~/.ssh/id_rsa_router.pub admin@192.168.88.1:key.pub
```

### 3. Import Command (RouterOS)

```routeros
/user ssh-keys import user=admin public-key-file=key.pub
```

### 4. Verification

```routeros
/user ssh-keys print detail
# Flags: R - RSA, E - Ed25519
#  0 user=admin key-type=rsa bits=4096 info="your_user"
#  1 user=admin key-type=ed25519 bits=256 info="your_user"
```

---

## ⚠️ Constraints & Gotchas

### Anti-Patterns (LLM Traps)

| ❌ Don't Assume          | ✅ Correct                                     |
| :----------------------- | :--------------------------------------------- |
| Ed25519 is unsupported   | **Ed25519 WORKS** for public keys (User Auth). |
| ECDSA works              | ECDSA is **UNSUPPORTED**.                      |
| File stays on disk       | File is **deleted** on success.                |
| Duplicate keys rejected  | Duplicates are **allowed** (messy).            |
| `private-key-file` param | Use `public-key-file` for user imports.        |
| `key-type` parameter     | No such parameter. Auto-detected from file.    |

### Contextual Support Helper

| Context                      | RSA 2048+ | Ed25519 |
| :--------------------------- | :-------- | :------ |
| **User Login (Incoming)**    | ✅ YES    | ✅ YES  |
| **Router Client (Outgoing)** | ✅ YES    | ❌ NO   |

---

## 🧪 Experiment Methodology

1.  **Generation**: `ssh-keygen` for all types.
2.  **Upload**: SCP to CHR.
3.  **Import**: `/user ssh-keys import`.
4.  **Auth Test**: `ssh -i <key> user@router` confirmed login.
5.  **Negative Tests**: ECDSA (Fail), RSA 1024 (Fail).

---

> **Keywords:** _RouterOS 7, SSH User Keys, Public Key Import, RSA, Ed25519, Passwordless Login_
