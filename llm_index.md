# RouterOS 7 LLM-Safe Reference Index

This index serves as the **authoritative map** for AI agents. It links user intents to specific verified references.
**INSTRUCTION**: Before generating any RouterOS code, locate the relevant topic below and **READ** the corresponding `.rsc` or `.md` file. This is mandatory to prevent hallucinations.

## 1. Core Syntax & Basics

- **File**: `references/core.rsc`
- **Link**: [references/core.rsc](references/core.rsc)
- **Topics**: Basic syntax, command structure, general scripting.
- **Instruction**: Read this file for all general scripting tasks to ensure adherence to basic RouterOS 7 syntax rules.

## 2. Date, Time & Certificates

- **File**: `references/datetime.rsc`
- **Link**: [references/datetime.rsc](references/datetime.rsc)
- **Topics**: Time arithmetic, ISO 8601 dates, certificate management, logging timestamps, scheduling.
- **Instruction**: Read this file when working with schedules, expiration checks, NTP, or any logic involving date and time manipulation. Ensure you use the correct ISO formats and time arithmetic as demonstrated.

## 2a. JSON & DSV Serialization

- **File**: `references/json.rsc`
- **Link**: [references/json.rsc](references/json.rsc)
- **Topics**: `:serialize`, `:deserialize`, JSON encoding/decoding, DSV/CSV handling, type mapping, options.
- **Instruction**: Read this file when working with JSON parsing, API responses, CSV export, or any data serialization. CRITICAL: Be aware of numeric string conversion behavior and use `json.no-string-conversion` option when needed.

## 3. Asynchronous & Blocking Operations

- **File**: `references/async.rsc`
- **Link**: [references/async.rsc](references/async.rsc)
- **Topics**: Blocking commands (traps), asynchronous execution, `/tool fetch`, background jobs.
- **Instruction**: Read this file to distinguish between blocking and non-blocking commands. CRITICAL for understanding why commands like `/tool fetch` are synchronous and how to properly handle long-running operations.

## 4. Error Handling & Reliability

- **File**: `references/errors.rsc`
- **Link**: [references/errors.rsc](references/errors.rsc)
- **Topics**: `:onerror`, `:retry`, script termination (`:quit`), error trapping.
- **Instruction**: Read this file when writing mission-critical automation that requires robust error handling and recovery mechanisms.

## 5. Control Flow & Logic

- **File**: `references/flow.rsc`
- **Link**: [references/flow.rsc](references/flow.rsc)
- **Topics**: Loops (`:foreach`, `:for`, `:while`), conditionals (`:if`), logic branching.
- **Instruction**: Read this file for any complex logic. Pay special attention to the absence of `:elseif` and the correct usage of loops to avoid syntax errors.

## 6. Types & Coercion

- **File**: `references/types.rsc`
- **Link**: [references/types.rsc](references/types.rsc)
- **Topics**: specialized types (IP, MAC), type conversion, `:tonsec`, mathematical operations, strict typing.
- **Instruction**: Read this file for tasks involving IP math, type checks, or value conversions. Note specifically that `:tonsec` returns nanoseconds.

## 7. String Escaping & Nesting

- **File**: `references/escaping.rsc`
- **Link**: [references/escaping.rsc](references/escaping.rsc)
- **Topics**: Nested quoting, dynamic script generation (scheduler/netwatch), string manipulation.
- **Instruction**: Read this file when taking strings that contain code (e.g., adding a script to a scheduler) to handle multiple levels of escaping correctly (up to 3 levels).

## 8. Variable Scope & Functions

- **File**: `references/scope.rsc`
- **Link**: [references/scope.rsc](references/scope.rsc)
- **Topics**: Global vs. local scope, environment constraints, function libraries.
- **Instruction**: Read this file to understand variable visibility and how to properly share data between scripts or functions.

## 9. Anti-Patterns & Hallucination Prevention

- **File**: `references/anti-patterns.rsc`
- **Link**: [references/anti-patterns.rsc](references/anti-patterns.rsc)
- **Topics**: Common AI errors, non-existent commands, deprecated syntax, fake parameters.
- **Instruction**: **ALWAYS** read this file to error-check your generated code against known common hallucinations. If your generated code matches an anti-pattern here, DISCARD IT and use the corrected approach.

## 10. Safe-Mode Transactions

- **File**: `references/safe-mode.rsc`
- **Link**: [references/safe-mode.rsc](references/safe-mode.rsc)
- **Topics**: Transaction safety, rollback/commit, session-based changes, return types, error handling, micro-transactions with `:execute`, coverage limitations (certificates NOT tracked).
- **Instruction**: Read this file when generating scripts that modify critical connectivity (firewall, interfaces, routes). **CRITICAL WARNINGS**:
  - Safe-mode requires PTY allocation (`ssh -tt`), fails silently without it
  - Rollback ONLY works on session termination, NOT on script `:error`
  - Certificates, log entries, global variables are NOT protected
  - `:execute` can enable micro-transactions with automatic rollback on subprocess failure (see Section 13)

## 11. Empirical Insights (Deep Dives)

- **File**: `insights/acme-client-behavior.md`
- **Link**: [insights/acme-client-behavior.md](insights/acme-client-behavior.md)
- **Topics**: ACME, Let's Encrypt, renewal logic, port 80 requirements.
- **Instruction**: Read this when automating certificate management.

- **File**: `insights/ssh-private-key-import.md`
- **Link**: [insights/ssh-private-key-import.md](insights/ssh-private-key-import.md)
- **Topics**: SSH keys, private key import, key formats (PEM), key types (RSA).
- **Instruction**: Read this prior to generating or importing SSH keys for router-initiated connections.

- **File**: `insights/ssh-public-key-import.md`
- **Link**: [insights/ssh-public-key-import.md](insights/ssh-public-key-import.md)
- **Topics**: SSH user auth, public key import, Ed25519 support, key formats.
- **Instruction**: Read this when automating user access or passwordless login TO the router.

- **File**: `insights/ssh-automation-execution.md`
- **Link**: [insights/ssh-automation-execution.md](insights/ssh-automation-execution.md)
- **Topics**: `ssh-exec`, output capture, automation barriers (TOFU), scripting execution contexts.
- **Instruction**: Read this when designing scripts that need to execute commands on remote routers via SSH.

- **File**: `insights/llm-api-communication.md`
- **Link**: [insights/llm-api-communication.md](insights/llm-api-communication.md)
- **Topics**: JSON API integration, LLM request/response patterns, `/tool fetch` security (`check-certificate=yes`), built-in CA store.
- **Instruction**: Read this when generating scripts that communicate with LLM APIs (OpenAI, Anthropic, etc.). CRITICAL: Follow the security and JSON serialization best practices.
