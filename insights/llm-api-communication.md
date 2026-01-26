# Grand Truth: RouterOS LLM API Communication Patterns

> **Verified By:** Real Anthropic Claude API Test (Jan 2026)
> **Status:** DEFINITIVE. Do not guess. Follow this strictly.
> **Scope:** RouterOS v7.21+
> **Related:** [references/json.rsc](../references/json.rsc), [references/async.rsc](../references/async.rsc)

---

## 1. The Request/Response Pattern

**Question:** How do I call an LLM API from RouterOS?
**Answer:** Use `/tool fetch` with `:serialize` for request body and `:deserialize` for response parsing.

```routeros
# Step 1: Build request body (use json.no-string-conversion!)
:local reqBody [:serialize to=json value={
  "model"="your-model-name";
  "max_tokens"=100;
  "messages"={{"role"="user";"content"="Hello"}}
} options=json.no-string-conversion];

# Step 2: Make HTTP request (BLOCKING!)
:local result [/tool fetch url="https://api.example.com/v1/messages" \
  http-method=post \
  http-header-field="Authorization: Bearer YOUR_API_KEY,Content-Type: application/json" \
  http-data=$reqBody \
  output=user \
  as-value];

# Step 3: Parse response
:local resp [:deserialize from=json value=($result->"data")];
```

> **Critical:** `/tool fetch` is **BLOCKING**. Script halts until response arrives.
> See [async.rsc](../references/async.rsc) RULE 5.1 for background execution pattern.

---

## 2. TLS Security (CRITICAL!)

**Question:** How do I secure API communications?
**Answer:** Use `check-certificate=yes` and the built-in CA store (RouterOS 7.19+).

### Built-in CA Store (7.19+)

RouterOS 7.19+ includes a **built-in root CA store** with major providers:

- Amazon Root CA
- DigiCert (Global, Assured ID, High Assurance EV, TLS)
- GlobalSign (Root CA, R3, R6, E46, R46)
- Let's Encrypt (ISRG Root X1, X2)
- Sectigo, USERTrust, GoDaddy

```routeros
# View available built-in certificates
/certificate/builtin/print

# Check current trust store settings
:put [/certificate/settings/get builtin-trust-store]
# => all (default)
```

### Fine-Grained Trust (7.21+)

RouterOS 7.21+ allows restricting which services use the built-in store:

```routeros
# Allow only fetch and DNS to use built-in CAs
/certificate/settings/set builtin-trust-store=fetch,dns

# Available values: all | container | dns | email | fetch | lora | mqtt | netwatch | untrusted
```

### Secure API Call Pattern

```routeros
# ALWAYS use check-certificate=yes for LLM APIs!
:local result [/tool fetch url="https://api.anthropic.com/v1/messages" \
  http-method=post \
  http-header-field="x-api-key: $apiKey,anthropic-version: 2023-06-01,content-type: application/json" \
  http-data=$reqBody \
  output=user \
  check-certificate=yes \
  as-value];
```

> ⚠️ **WARNING:** RouterOS defaults to `check-certificate=no` for legacy compatibility!
> You MUST explicitly set `check-certificate=yes` for secure LLM API calls.
> API keys transmitted without TLS verification can be intercepted (MITM attacks).

---

## 3. Response Access Patterns

**Question:** How do I extract the LLM's response text?
**Answer:** Use chained `->` operators for nested array/object access.

| API Style | Response Structure                | Access Pattern                              |
| :-------- | :-------------------------------- | :------------------------------------------ |
| Anthropic | `{content:[{type,text}]}`         | `$resp->"content"->0->"text"`               |
| OpenAI    | `{choices:[{message:{content}}]}` | `$resp->"choices"->0->"message"->"content"` |
| Generic   | `{data:{result}}`                 | `$resp->"data"->"result"`                   |

**Verified Example (Real Anthropic Response):**

```routeros
# Response: {"content":[{"type":"text","text":"Hello, how are you today?"}],...}
:put ($resp->"content"->0->"text");       # => Hello, how are you today?
:put ($resp->"usage"->"input_tokens");    # => 16
:put ($resp->"usage"->"output_tokens");   # => 10
```

> See [json.rsc](../references/json.rsc) RULE 2.4 for combined array→object access.

---

## 4. Multi-Part Response Handling

**Question:** What if the response has multiple content blocks?
**Answer:** Use `:foreach` to iterate over content array.

```routeros
:foreach block in=($resp->"content") do={
  :if (($block->"type") = "text") do={
    :put ($block->"text");
  };
};
```

---

## 5. Error Handling

**Question:** How do I handle API errors?
**Answer:** Wrap in `:onerror` and check response structure.

```routeros
:onerror e in={
  :local result [/tool fetch ... as-value];
  :local resp [:deserialize from=json value=($result->"data")];

  # Check for error response
  :if (($resp->"type") = "error") do={
    :log error ("API Error: " . ($resp->"error"->"message"));
    :error "API call failed";
  };

  # Process success response
  :local text ($resp->"content"->0->"text");
  :put $text;
} do={
  :log error ("Request failed: " . $e);
};
```

> See [json.rsc](../references/json.rsc) RULE 6.4: Missing keys return `nothing`, not error.

---

## 6. Safe Access Pattern

**Question:** What if expected fields are missing?
**Answer:** Missing keys return `nothing` type (NOT an error). Check before use.

```routeros
:local content ($resp->"content"->0->"text");
:if ([:typeof $content] = "nothing") do={
  :log error "No content in response";
} else={
  :put $content;
};
```

---

## 7. Storing Response for Later Use

**Question:** How do I save the response for other scripts?
**Answer:** Use global variables.

```routeros
:global lastLLMResponse ($resp->"content"->0->"text");

# Later, in another script:
:global lastLLMResponse;
:put $lastLLMResponse;
```

> **Warning:** Globals persist until reboot. Clean up when done.

---

## 8. Background Execution Pattern

**Question:** How do I avoid blocking the main script?
**Answer:** Wrap in `:execute` for async operation.

```routeros
# Fire-and-forget (use global for result)
[:execute "/system script run llm-query-script"];

# Or inline with escaped quotes
:local job [:execute ("/tool fetch url=\\\"...\\\" ...")];
```

> See [async.rsc](../references/async.rsc) RULE 5.1 and Pattern A (The Wrapper).

---

## 📉 Summary Checklist for AI Agents

1. [ ] **TLS Security**: Use `check-certificate=yes` (7.19+ has built-in CA store)
2. [ ] **Serialize**: Use `json.no-string-conversion` to preserve string IDs
3. [ ] **Fetch**: Remember it's **BLOCKING** - wrap in `:execute` if needed
4. [ ] **Headers**: Comma-separated in single `http-header-field` parameter
5. [ ] **Parse**: Use `:deserialize from=json value=($result->"data")`
6. [ ] **Access**: Chain `->` operators: `$resp->"key"->0->"nested"`
7. [ ] **Errors**: Wrap in `:onerror`, check `$resp->"type"` for error responses
8. [ ] **Missing Keys**: Return `nothing`, not error - check with `[:typeof ...]`
