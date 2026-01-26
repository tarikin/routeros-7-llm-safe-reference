# Grand Truth: RouterOS SSH Automation & Execution

> **Verified By:** 50+ Brute-Force Tests (Jan 2026)
> **Status:** DEFINITIVE. Do not guess. Follow this strictly.
> **Scope:** RouterOS v7.22+

---

## 1. The Context "Sudo" Paradox

**Question:** Who owns the execution?
**Answer:** The **Caller** owns the execution, NOT the Script Owner, unless strictly spawned by Scheduler.

| Invocation Method             | Effective Context        | Key Store Used     | Result (Run as `test-user`, Owner `api-ssh`)      |
| :---------------------------- | :----------------------- | :----------------- | :------------------------------------------------ |
| `/system script run`          | **Caller** (`test-user`) | `test-user`'s keys | ❌ **FAIL** (Auth - Uses Caller's empty keys)     |
| `:execute script=...`         | **Caller** (`test-user`) | `test-user`'s keys | ❌ **FAIL** (Auth)                                |
| `/system scheduler`           | **Script Owner** (`api`) | `api`'s keys       | ✅ **PASS** (Even if Sched Owner != Script Owner) |
| `/tool netwatch`              | **System** (`sys`)       | No keys            | ❌ **FAIL**                                       |
| `api` runs own script         | **Caller** (`api`)       | `api`'s keys       | ✅ **PASS**                                       |
| `api` runs `test-user` script | **Caller** (`api`)       | `api`'s keys       | ✅ **PASS** (Context = Caller)                    |

> **Critical Distinction:**
>
> - **Manual Execution**: Uses **Caller's** Identity. (Ignores Script Owner).
> - **Scheduler Execution**: Uses **Script Owner's** Identity. (Even if scheduled by Admin).

> **Rule:** You cannot "sudo" a script. To test automation, you MUST trigger it via **Scheduler** or log in AS the service user. Use `api-ssh` user for ALL automation.

---

## 2. Execution Primitives: The "Hang" Myth

**Question:** Does `ssh` hang my script?
**Answer:** Interactive `ssh` **FAILS FAST** in scripts (no PTY). `ssh-exec` is always Synchronous.

| Command                          | In Console        | In Script (Run/Sched) | Behavior                                                     |
| :------------------------------- | :---------------- | :-------------------- | :----------------------------------------------------------- |
| `/system ssh`                    | Interactive Shell | ❌ **FAIL-FAST**      | Exits immediately: "Terminal not prompting". Does NOT hang.  |
| `/system ssh-exec`               | One-shot output   | ✅ **PASS**           | **Synchronous/Blocking**. Waits for remote command.          |
| `:execute "/system ssh..."`      | Async Job         | ⚠️ **ZOMBIES**        | Creates a job, but `ssh` process dies instantly (fail-fast). |
| `:execute "/system ssh-exec..."` | Async Job         | ✅ **PASS**           | Runs in background. Safe.                                    |

> **Rule:** NEVER use `/system ssh` in scripts. It will not work. Use `/system ssh-exec`.

---

## 3. Output Capture: The "Null" Problem

**Question:** How do I capture the output?
**Answer:** **Native** `output-to-file` is the ONLY reliable method. Direct variable capture is BROKEN for `ssh-exec`.

| Method             | Syntax                                           | Reliability          | Result                                     |
| :----------------- | :----------------------------------------------- | :------------------- | :----------------------------------------- |
| **Native File**    | `/system ssh-exec ... output-to-file=result.txt` | 🌟 **GOLD STANDARD** | **WORKS**. Captures full output.           |
| **Execute String** | `:local r [:execute ... as-string]`              | ❌ **BROKEN**        | Returns EMPTY string `""` despite success. |
| **Execute File**   | `:execute ... file=result`                       | ❌ **BROKEN**        | Captures only exit metadata, not content.  |

> **Workaround Pattern:**
>
> 1. Run `ssh-exec ... output-to-file=temp.txt`
> 2. `:delay 1s`
> 3. `:local content [/file get temp.txt contents]`
> 4. `/file remove temp.txt`

---

## 4. Permissions & Policy

**Question:** What policies matter?
**Answer:** User policy trumps Script policy for Execution Context.

- **Run Command**: Bypasses Script Policy (uses Active User's Policy).
- **Scheduler**: Enforces strict intersection.
- **SSH-Exec**: Requires `ssh`, `read`, and (if capturing) `write` policies.

---

## 5. TOFU (Trust On First Use) Barrier

**Question:** Can I accept host keys automatically?
**Answer:** **NO.**

- **New Host**: `ssh-exec` fails immediately (`authentication failure`).
- **Interactive**: Prompts `yes/no` (requires PTY, impossible in automated scripts).
- **Solution**: You MUST perform **One Manual Handshake** (or use an external PTY wrapper) to populate `known_hosts` before simple automation works.

---

## 📉 Summary Checklist for AI Agents

1.  [ ] **User**: Always run AS `api-ssh` (or Scheduler owned by `api-ssh`).
2.  [ ] **Command**: Use `/system ssh-exec`.
3.  [ ] **Capture**: Use `output-to-file=...`. Do NOT use `:execute as-string`.
4.  [ ] **Trust**: Verify host key manually once.
5.  [ ] **Syntax**: Use **Single Quotes** `'...'` for checking commands externally to protect RouterOS variables.
