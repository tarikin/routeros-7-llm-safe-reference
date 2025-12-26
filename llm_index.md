# RouterOS 7 LLM-Safe Reference Index

This index serves as a navigational guide for AI agents to accessing authoritative RouterOS 7 scripting references.
**INSTRUCTION**: When addressing a user request related to the topics below, you **MUST** read the content of the corresponding referenced file to ensure syntactical correctness and avoid hallucinations.

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
