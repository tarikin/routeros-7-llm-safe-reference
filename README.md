# RouterOS 7 LLM-Safe Reference 🚀

> **The Ultimate Grounding Context for AI-Powered Network Automation**
>
> 🛡️ **Empirically Verified on RouterOS 7.21+ | January 2026**  
> 🤖 **Compatible with:** OpenAI GPT · Anthropic Claude · Google Gemini · Meta LLaMA · xAI Grok · DeepSeek · Perplexity · Cursor · Windsurf · GitHub Copilot · Antigravity

---

## ❓ What Is This?

A curated set of **`.rsc` reference files** designed to be **injected into AI agent prompts** (system prompts, RAG pipelines, or direct context windows). These files act as **Truth Anchors**—forcing LLMs to generate RouterOS 7 scripts that are **syntactically correct**, **semantically valid**, and **free of hallucinations**.

> **TL;DR:** Stop your AI from inventing fake commands. Feed it verified reality.

---

## 🔥 Who Is This For?

| Persona                       | Use Case                                                                     |
| ----------------------------- | ---------------------------------------------------------------------------- |
| **Prompt Engineers**          | Inject `.rsc` files into system prompts for constraint-guided generation     |
| **Network Architects**        | Generate reliable automation scripts without manual syntax debugging         |
| **DevOps / NetMLOps**         | Build self-healing infrastructure with AI-assisted scripting                 |
| **MikroTik Enthusiasts**      | "Vibe-script" with confidence—let AI handle the syntax, you handle the logic |
| **Agentic Workflow Builders** | Ground multi-step reasoning agents with verified network primitives          |

---

## 📚 The Reference Collection

Each file is **battle-tested** on real RouterOS 7.21 hardware. Use them as context for your AI:

| File                               | Purpose                                          | When to Use                                       |
| ---------------------------------- | ------------------------------------------------ | ------------------------------------------------- |
| **`references/core.rsc`**          | Core syntax cheatsheet                           | General scripting, quick tasks                    |
| **`references/datetime.rsc`**      | Time, dates, certificates, logs                  | Scheduling, expiration checks, NTP                |
| **`references/async.rsc`**         | Blocking vs async behavior                       | `:execute`, `/tool fetch`, jobs                   |
| **`references/errors.rsc`**        | `:onerror`, `:retry`, `:quit`                    | Mission-critical automation                       |
| **`references/flow.rsc`**          | Loops, conditionals, control flow                | Complex logic (no `:break` trap!)                 |
| **`references/types.rsc`**         | Type system, coercion, `:tonsec`                 | Math, IP operations, type checks                  |
| **`references/escaping.rsc`**      | Nested quotes, scheduler strings                 | Deep nesting (up to 3 levels)                     |
| **`references/scope.rsc`**         | Variable scoping, `:global`/`:local`             | Function design, closures                         |
| **`references/anti-patterns.rsc`** | 60+ documented hallucinations                    | **LLM-only** — prevents bad patterns              |
| **`references/safe-mode.rsc`**     | Transaction safety, rollback, micro-transactions | PTY sessions, `:execute` atomics, coverage limits |

---

## 🚀 Changelog

### January 2026

Safe-mode deep dive with **50+ empirical tests** on CHR 7.21:

- ✅ **Return Types**: Full type audit (`take`→nil, `release`→bool, property types by state)
- ✅ **Coverage Limits**: Certificates NOT tracked, files ARE tracked (all platforms)
- ✅ **Micro-Transactions**: `:execute` + `on-error=unroll` enables scripted rollback
- ✅ **11 Anti-Patterns**: PTY requirement, external side-effects, global variables
- ✅ **PTY Discovery**: Safe-mode silently fails without `ssh -tt`

### December 2025

Massive expansion with **500+ empirical tests** across 20 categories:

- ✅ **ISO 8601 Dates**: Validated v7.10+ format (`YYYY-MM-DD`), not old `MMM/DD/YYYY`
- ✅ **Time Arithmetic**: Confirmed `23h + 3h = 1d02:00:00` (no 24h wrap)
- ✅ **Blocking Traps**: Identified `/tool fetch`, `/certificate sign`, `/tool e-mail` as synchronous
- ✅ **Type Precision**: Documented `:tonsec` as **nanoseconds** (not seconds!)
- ✅ **Anti-Patterns**: Catalogued 60+ common LLM hallucinations with corrections

---

## 💡 How to Use

### For Chat-Based AI (GPT, Claude, Gemini)

```
You are an expert in MikroTik RouterOS 7.
Below is a verified reference to ensure correct syntax:

[PASTE mini-ref.rsc HERE]

Generate a script that [YOUR TASK].
Follow the reference syntax exactly—no invented commands.
```

### For Agentic Workflows (RAG, Tool-Use)

1. **Index** the `.rsc` files in your vector database
2. **Retrieve** relevant chunks based on user query (e.g., "scheduler" → `datetime-ref.rsc`)
3. **Inject** retrieved context into agent's working memory
4. **Generate** with grounded constraints

### For IDE Copilots (Cursor, Windsurf, Copilot)

- Add `.rsc` files to your project
- Reference them in comments: `// See async-ref.rsc for blocking behavior`
- Copilot will respect the context automatically

---

## 🛡️ Why This Works

| Problem                                | Solution                              |
| -------------------------------------- | ------------------------------------- |
| LLMs invent `:elseif`                  | `flow-ref.rsc` shows it doesn't exist |
| LLMs assume `fetch` is async           | `async-ref.rsc` proves it blocks      |
| LLMs use old date formats              | `datetime-ref.rsc` verifies ISO       |
| LLMs guess type conversions            | `types-ref.rsc` maps all coercions    |
| LLMs assume safe-mode works in scripts | `safe-mode.rsc` proves PTY required   |

> **Empirical Truth > Training Data Noise**

---

## 🔗 Quick Links

- [**Prompt Library**](docs/prompt-library.md) — Real-world automation prompts
- [**CLI Menu Structure**](docs/cli-map.md) — Full command hierarchy
- [**Anti-Patterns Catalog**](references/anti-patterns.rsc) — What NOT to generate

## 🧠 Empirical Insights

Deep dives into specific RouterOS behaviors, established through rigorous testing:

| Topic                                                            | Description                                            |
| :--------------------------------------------------------------- | :----------------------------------------------------- |
| [**ACME Client Behavior**](insights/acme-client-behavior.md)     | Renewal logic, auth caching, and scheduler constraints |
| [**SSH Private Key Import**](insights/ssh-private-key-import.md) | Key types (RSA only), PEM format, and import quirks    |

---

## 🧪 Validation Tip

Test AI-generated scripts before deployment:

```bash
/system script add name=Test
/system script edit Test value-name=source
# Paste script → Editor highlights syntax errors
```

> ⚠️ Syntax validation only—runtime behavior requires live testing.

---

## 🤝 Contributing

1. **Fork** → **Branch** → **PR**
2. All contributions tested with AI + manual verification
3. Focus: Conciseness, accuracy, LLM-friendliness

---

## 📜 License

[MIT License](LICENSE) — Use freely, attribute kindly.

---

## 👤 Author

**Nikita Tarikin** — Network Infrastructure Architect & AI-Driven Automation  
[GitHub](https://github.com/tarikin) · [LinkedIn](https://linkedin.com/in/nikita-tarikin) · [tarikin.com](https://tarikin.com)

---

> **Keywords:** _RouterOS 7, MikroTik Scripting, AI Network Automation, LLM Grounding, RAG for Networks, Hallucination-Free Code Generation, Agentic NetDevOps, Context Injection, Self-Healing Infrastructure, Prompt Engineering, Constraint-Guided Generation, Vibe-Scripting, Infrastructure-as-Code, Network Reliability Engineering_
