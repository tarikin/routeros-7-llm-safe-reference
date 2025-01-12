# RouterOS 7 LLM-Safe Reference

> **“Token-Efficient Scripting for AI-Driven RouterOS Tasks”**  

A minimal, battle-tested RouterOS 7 scripting snippet—designed **specifically** to be **attached** to Large Language Model (LLM) prompts (e.g., ChatGPT, Claude) so that AI remains grounded in **real**, **verified** commands.  

## Why This Repository?

1. **Eliminate Hallucinations**: Attach or paste `mini-ref.rsc` into your LLM prompts to enforce correct RouterOS syntax, bypassing “dream code.”  
2. **Token-Efficient**: The snippet is carefully curated to include essential commands—no fluff, ensuring each token guides the LLM toward **accurate** output.  
3. **Advanced Error Handling**: Utilizes `:retry`, `:onerror`, and robust control structures to showcase best practices.  
4. **Deep Integration**: Covers JSON, DSV, array/dictionary manipulation, `execute` calls, and more for real-world automation tasks.  

## How It Works

Rather than reading this snippet manually, you **provide** `mini-ref.rsc` to your LLM whenever you need it to write or refine RouterOS scripts. Including the snippet in your prompt is the key—LLMs learn from every line and produce scripts that align with verified syntax.  

## Example Usage

When you talk to ChatGPT or Claude, **reference** the lines from `mini-ref.rsc` to guide script generation.  

### Sample Prompt #1: Basic Usage
```
You are an expert in MikroTik RouterOS 7.  
Here's a verified reference snippet (lines 10-30) to ensure correct syntax:  
[PASTE mini-ref.rsc LINES 10-30 HERE]

Please create a script to add a firewall filter that drops traffic from 1.2.3.4, 
using the same formatting and syntax as the reference.
```

**Result**: The LLM will pull correct syntax from lines 10–30, ensuring no guesswork.  

### Sample Prompt #2: Optimizing Existing Script
```
You are ChatGPT, specialized in RouterOS. 
Below is a reference snippet to avoid syntax errors: 
[PASTE FULL mini-ref.rsc HERE]

I have a script that times out occasionally. 
Please optimize it, ensuring each function aligns with the reference’s approach, 
especially the :retry logic and do{} while=() loops.
```

**Result**: The LLM merges your existing script with the snippet’s proven patterns for error handling.  

### Sample Prompt #3: JSON/DSV Data Handling
```
You are an AI that must strictly follow the syntax in the attached RouterOS snippet: 
[PASTE mini-ref.rsc LINES 70–90]

Given a remote server returning JSON data, generate a script that fetches, 
deserializes, and logs each key-value pair. 
Use the reference approach for JSON and DSV.
```

**Result**: The LLM references lines 70–90 to produce correct code for JSON/DSV operations.  

### Ultimate Prompt for Edge Performance
```
You are an advanced RouterOS 7 automation specialist, strictly confined to the 
syntax from the attached reference snippet:
[PASTE FULL mini-ref.rsc HERE]

Scenario: 
- We have an NTP sync requirement 
- We must fetch new config data in JSON 
- We want a :retry mechanism if fetch fails 
- We validate the "status" field from the JSON 
- If not "active", we append a new array element 
- Then beep at 300Hz for 500ms if everything succeeds.

Generate a single cohesive script that does all of this, 
strictly following the snippet’s approach, no extra commands or guesswork.
```

**Result**: The LLM delivers a meticulously accurate script, leveraging the snippet’s array, JSON, and beep logic.  

## Contributing

We welcome new commands or formatting tweaks that help keep the snippet concise yet comprehensive. Submit a PR, and we’ll test your additions with ChatGPT or Claude for syntactic accuracy.

1. **Fork** this repo  
2. **Branch** your changes  
3. **Submit** a Pull Request detailing improvements  
4. **AI + Manual Review** ensures final correctness  

## License

Open-sourced under the [MIT License](LICENSE).  

## About the Author

**Nikita Tarikin** – MikroTik Network Infrastructure Architect & AI-Enhanced Solutions  
- [GitHub](https://github.com/tarikin)  
- [LinkedIn](https://www.linkedin.com/in/nikita-tarikin/)  
- [Website](https://tarikin.com/)  

> **Use `mini-ref.rsc` as your LLM truth source.** Keep it attached to your AI prompts, and watch your RouterOS scripts reach new levels of consistency and accuracy!
