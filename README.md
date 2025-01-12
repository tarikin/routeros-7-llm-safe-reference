# RouterOS 7 LLM-Safe Reference

> **“Token-Efficient RouterOS Scripting for AI-Driven Automation”**

A minimal, battle-tested RouterOS 7 scripting snippet co-developed with **ChatGPT o1-pro**.

This reference **reduces** AI hallucinations by providing **concise** commands and verified syntax.

## Why This Repository?

- **Close Gaps** in RouterOS official documentation and address common LLM mistakes.
- **Empower** network professionals to integrate AI into daily network tasks safely.
- **Encourage** community improvements—each PR is AI-audited for syntax accuracy.
- **Highlight** ChatGPT o1-pro’s role in distilling, verifying, and refining code.

## Key Features

- **Token-Efficient Script**: Minimizes ambiguous lines that lead to LLM guesswork.
- **Real-World Tested**: Pulled from actual MikroTik deployments and verified by ChatGPT.
- **JSON & DSV** Usage: Showcases advanced data handling in RouterOS.
- **Robust Error Handling**: :retry, :onerror, do{}while=() loops, and more.

## Getting Started

1. **Clone This Repo**

```bash
git clone git@github.com:tarikin/routeros-7-llm-safe-reference.git
cd routeros-7-llm-safe-reference
```

2. **Review the Mini-Reference** in `mini-ref.rsc` (or see below).
3. **Copy-Paste** relevant portions into your RouterOS environment (WinBox, SSH).
4. **Use with AI** (ChatGPT, Claude, etc.) by referencing lines from `mini-ref.rsc` to keep the LLM grounded.

## How to Use with ChatGPT or Anthropic Claude

- **Sample Prompt**:

```prompt
You are an expert in MikroTik RouterOS 7 scripting.  
Refer to lines 12-20 of the attached “RouterOS 7 LLM-Safe Reference”.  
Based on that syntax, extend the script for firewall filter rules.
```

- This method enforces **accurate** syntax, reducing mistakes from hallucination.

## Contributing

We **welcome** your PRs—**AI** (ChatGPT or Claude) can assist in verifying syntax, but **manual** oversight ensures final correctness.

1. **Fork** this repository
2. **Create** a new branch with your improvements
3. **Open** a Pull Request, describing why your changes help
4. We’ll run your snippet through ChatGPT o1-pro for an additional syntax check

## License

Released under the [MIT License](LICENSE).

## About the Author

**Nikita Tarikin** - MikroTik Network Infrastructure Architect & AI-Enhanced Network Solutions Expert

- [GitHub](https://github.com/tarikin) | [LinkedIn](https://www.linkedin.com/in/nikita-tarikin/) | [Website](https://tarikin.com/)

