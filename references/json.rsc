# RouterOS 7 JSON Serialization Reference
# VERIFIED on RouterOS 7.21+ and 7.22beta5
# This document contains ONLY empirically verified JSON behavior

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      1. :serialize to=json                                  │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 1.1: Basic JSON serialization syntax
:local json [:serialize to=json value={"a"=1;"b"=2}];
:put $json;                               # => {"a":1,"b":2}
:put [:typeof $json];                     # => str

# RULE 1.2: file-name parameter writes to file instead of returning
:local result [:serialize to=json value={"test"=1} file-name="out.json"];
:put $result;                             # => (empty string)
# File "out.json" created on router filesystem

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      2. :deserialize from=json                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 2.1: Basic JSON deserialization
:local obj [:deserialize from=json value="{\"a\":1,\"b\":2}"];
:put ($obj->"a");                         # => 1
:put [:typeof $obj];                      # => array

# RULE 2.2: Access nested fields with -> operator
:local deep [:deserialize from=json value="{\"outer\":{\"inner\":\"value\"}}"];
:put ($deep->"outer"->"inner");           # => value

# RULE 2.3: Access array elements by index (0-based)
:local arr [:deserialize from=json value="[\"a\",\"b\",\"c\"]"];
:put ($arr->0);                           # => a
:put ($arr->2);                           # => c

# RULE 2.4: Combined array->object access (critical for API responses!)
:local resp [:deserialize from=json value="{\"items\":[{\"id\":1},{\"id\":2}]}"];
:put ($resp->"items"->0->"id");           # => 1
:put ($resp->"items"->1->"id");           # => 2

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      3. TYPE MAPPING (RouterOS <-> JSON)                    │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 3.1: Primitive types serialize correctly
:put [:serialize to=json value=123];      # => 123 (num -> number)
:put [:serialize to=json value="text"];   # => "text" (str -> string)
:put [:serialize to=json value=true];     # => true (bool -> boolean)
:put [:serialize to=json value=false];    # => false

# RULE 3.2: nil and nothing both serialize to null
:local nilVal [];
:put [:serialize to=json value=$nilVal];  # => null
:local nothingVar;
:put [:serialize to=json value=$nothingVar]; # => null

# RULE 3.3: Network types serialize as STRINGS (type info lost!)
:put [:serialize to=json value=192.168.1.1];      # => "192.168.1.1"
:put [:serialize to=json value=2001:db8::1];      # => "2001:db8::1"
:put [:serialize to=json value=192.168.0.0/24];   # => "192.168.0.0/24"
:put [:serialize to=json value=1h30m15s];         # => "01:30:15"

# RULE 3.4: Arrays serialize to JSON arrays
:put [:serialize to=json value={1;2;3}];          # => [1,2,3]
:local emptyArr ({});
:put [:serialize to=json value=$emptyArr];        # => []

# RULE 3.5: Dictionaries serialize to JSON objects
:put [:serialize to=json value={"key"="val"}];    # => {"key":"val"}
:put [:serialize to=json value={"a"=1;"b"=2}];    # => {"a":1,"b":2}

# RULE 3.6: Nested structures work
:local deep {"outer"={"inner"={"deep"="value"}}};
:put [:serialize to=json value=$deep];    # => {"outer":{"inner":{"deep":"value"}}}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      4. NUMERIC STRING CONVERSION (CRITICAL!)               │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 4.1: Numeric strings CONVERT to JSON numbers by default!
:put [:serialize to=json value="123"];    # => 123.000000 (NOT "123"!)
:put [:serialize to=json value={"id"="456"}]; # => {"id":456.000000}

# RULE 4.2: Use json.no-string-conversion to preserve strings
:put [:serialize to=json value="123" options=json.no-string-conversion];
# => "123"
:put [:serialize to=json value={"id"="456"} options=json.no-string-conversion];
# => {"id":"456"}

# RULE 4.3: On deserialize, strings are INFERRED to types by default
:put [:typeof [:deserialize from=json value="\"192.168.1.1\""]]; # => ip
:put [:typeof [:deserialize from=json value="\"01:30:00\""]];    # => time
:put [:typeof [:deserialize from=json value="\"123\""]];         # => num (!)

# RULE 4.4: Use json.no-string-conversion on deserialize too
:put [:typeof [:deserialize from=json value="\"123\"" options=json.no-string-conversion]];
# => str (preserved!)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      5. JSON OPTIONS                                        │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 5.1: json.pretty formats with newlines/indentation
:put [:serialize to=json value={"a"=1} options=json.pretty];
# => {
#      "a": 1
#    }

# RULE 5.2: Combine multiple options with array syntax
:put [:serialize to=json value={"n"="1"} options=(json.pretty,json.no-string-conversion)];

# RULE 5.3: Options are CASE-SENSITIVE (lowercase only!)
# :put [:serialize to=json value=1 options=JSON.PRETTY]; # ERROR!
:put [:serialize to=json value=1 options=json.pretty];   # Correct

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      6. ERROR HANDLING                                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 6.1: Invalid JSON throws catchable error
:onerror e in={
  [:deserialize from=json value="{invalid}"];
} do={
  :put "caught JSON parse error";
};

# RULE 6.2: Missing required parameters throw errors
:onerror e in={
  [:serialize to=json];  # Missing value=
} do={
  :put "caught missing param";
};

# RULE 6.3: Trailing commas in JSON are tolerated (lenient parser)
:local r [:deserialize from=json value="[1,2,3,]"];
:put $r;                                  # => 1;2;3 (works!)

# RULE 6.4: Missing keys return "nothing" (NOT an error!)
:local obj [:deserialize from=json value="{\"a\":1}"];
:local missing ($obj->"nonexistent"->"deep");
:put [:typeof $missing];                  # => nothing

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      7. ROUND-TRIP BEHAVIOR                                 │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 7.1: Basic round-trip works for primitives
:local orig {"num"=123;"str"="text";"bool"=true};
:local json [:serialize to=json value=$orig];
:local back [:deserialize from=json value=$json];
:put ($back->"num");                      # => 123

# RULE 7.2: Network types: serialize as string, deserialize infers back
:local orig {"ip"=192.168.1.1};
:local json [:serialize to=json value=$orig];  # => {"ip":"192.168.1.1"}
:local back [:deserialize from=json value=$json];
:put [:typeof ($back->"ip")];             # => ip (inferred back!)

# RULE 7.3: Dict key ordering may change (alphabetical in JSON)
:local orig {"z"=1;"a"=2;"m"=3};
:local json [:serialize to=json value=$orig];
:put $json;                               # => {"a":2,"m":3,"z":1}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      QUICK REFERENCE TABLE                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌──────────────────┬───────────────────────────────────────────────────────────┐
# │ Command          │ Syntax                                                    │
# ├──────────────────┼───────────────────────────────────────────────────────────┤
# │ :serialize       │ [:serialize to=json value=$var options=...]              │
# │ :deserialize     │ [:deserialize from=json value=$str options=...]          │
# └──────────────────┴───────────────────────────────────────────────────────────┘
#
# ┌──────────────────┬───────────────────────────────────────────────────────────┐
# │ JSON Options     │ Purpose                                                   │
# ├──────────────────┼───────────────────────────────────────────────────────────┤
# │ json.pretty      │ Format with newlines and indentation                      │
# │ json.no-string-  │ Prevent "123"->123 conversion (CRITICAL!)                 │
# │   conversion     │                                                           │
# └──────────────────┴───────────────────────────────────────────────────────────┘
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ CRITICAL LLM PITFALLS                                                        │
# ├──────────────────────────────────────────────────────────────────────────────┤
# │ ✗ "123" serializes to 123 (number) without json.no-string-conversion        │
# │ ✗ "192.168.1.1" deserializes to ip type (auto-inference)                    │
# │ ✗ IP/time types serialize as strings - type info LOST on round-trip         │
# │ ✗ Options are case-sensitive: json.pretty works, JSON.PRETTY fails          │
# │ ✓ Empty array {} serializes to [] (not {})                                  │
# │ ✓ Dict key order is alphabetized in JSON output                             │
# │ ✓ Trailing commas in JSON input are tolerated                               │
# │ ✓ Nested structures (5+ levels) work correctly                              │
# │ ✓ Missing keys return "nothing", not error                                  │
# └──────────────────────────────────────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+
# ══════════════════════════════════════════════════════════════════════════════
