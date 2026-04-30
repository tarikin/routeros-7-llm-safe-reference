# RouterOS 7 JSON / DSV Serialization Reference
# VERIFIED on RouterOS 7.21+ baseline; 7.18+ DSV additions marked inline
# This document contains ONLY empirically verified JSON / DSV behavior

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

# RULE 4.1: Numeric strings CONVERT to JSON numbers by default (DESTRUCTIVE!)
# VERIFIED REF-AUDIT-JSON-NUMERIC-COERCE / REF-AUDIT-JSON-NO-STRING-CONVERSION
# 2026-04-30 7.23rc2.
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
# Quoted-numeric inputs `"1"` ALSO coerce to num by default — to keep them as
# strings, you MUST pass options=json.no-string-conversion (RULE 4.4).

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
# │                      8. DSV (DELIMITER-SEPARATED VALUES) — 7.18+            │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 8.1: :serialize to=dsv requires delimiter= (no default!)
:local s [:serialize to=dsv value=({1;2;3}) delimiter=","];
:put $s;                                  # => 1,2,3
:put [:serialize to=dsv value=({1;2;3}) delimiter=";"];   # => 1;2;3
:put [:serialize to=dsv value=({1;2;3}) delimiter="|"];   # => 1|2|3
# Without delimiter: Script Error: delimiter not specified (:serialize; line N)

# RULE 8.2: Tab delimiter — `\t` and `\09` both produce a literal 0x09 byte (7.18+)
:local tab1 [:serialize to=dsv value=({1;2;3}) delimiter="\t"];
:put $tab1;                               # => 1<TAB>2<TAB>3
:local tab2 [:serialize to=dsv value=({1;2;3}) delimiter="\09"];
:put ($tab1 = $tab2);                     # => true (identical bytes)

# RULE 8.3: dsv.remap — flatten array-of-dicts to header-row + data rows (7.18+)
# Header is sorted ALPHABETICALLY by key (NOT insertion order). Row values are
# emitted in header-column order. VERIFIED REF-AUDIT-JSON-DSV-KEY-ORDERING
# 2026-04-30 7.23rc2.
# This is THE killer feature for tabular output of `print as-value`.
:local rows ({{a=1;b=2};{a=3;b=4};{a=5;b=6}});
:put [:serialize to=dsv value=$rows delimiter="," options=dsv.remap];
# => a,b
# => 1,2
# => 3,4
# => 5,6

# RULE 8.4: dsv.remap on `print as-value` (real router data)
:local ifs [/interface print as-value];
:put [:serialize to=dsv value=$ifs delimiter="," options=dsv.remap];
# => .id,actual-mtu,disabled,mac-address,name,running,type
# => *2,1500,false,00:0C:29:26:62:E4,ether1,true,ether
# => *1,65536,false,00:00:00:00:00:00,lo,true,loopback

# RULE 8.5: dsv.remap on mixed-shape rows — header = union of row-0 keys, missing -> empty
:put [:serialize to=dsv value=({{a=1;b=2;c=3};{a=4;c=5}}) delimiter="," options=dsv.remap];
# => a,b,c
# => 1,2,3
# => 4,,5                                  (missing 'b' becomes empty cell)

# RULE 8.6: Without dsv.remap, array-of-dicts produces unhelpful key=value;... join
:put [:serialize to=dsv value=({{a=1;b=2};{a=3;b=4}}) delimiter=","];
# => a=1;b=2,a=3;b=4                       (rarely useful — always pair maps with dsv.remap)

# RULE 8.7: dsv.remap is REJECTED on FLAT scalar arrays — needs an outer array of inner dicts
# :serialize to=dsv value=({1;2;3}) options=dsv.remap;
# => Script Error: input not an array (:serialize; line N)

# RULE 8.8: dsv.wrap-strings — wrap string values in quotation marks (7.18+; alone only)
:put [:serialize to=dsv value=({"hi";"there"}) delimiter="," options=dsv.wrap-strings];
# => "hi","there"
# dsv.remap and dsv.wrap-strings are MUTUALLY EXCLUSIVE — combining via
# options=(dsv.remap,dsv.wrap-strings) raises catchable
# `Script Error: unsupported options (:serialize; line N)`. Single option only.
# VERIFIED REF-AUDIT-JSON-DSV-REMAP-WRAPSTR 2026-04-30 7.23rc2.

# RULE 8.9: :deserialize from=dsv default — column-oriented dict (header -> array of values)
:local back [:deserialize from=dsv value="a,b\n1,2\n3,4" delimiter=","];
:put [:typeof $back];                     # => array
:put ($back->"a");                        # => 1;3        (column 'a' as array)
:put ($back->"b");                        # => 2;4
:put [:typeof (($back->"a")->0)];         # => num        (type inference per cell)

# RULE 8.10: :deserialize options=dsv.array — header + rows -> array of dicts (7.18+)
:local rows [:deserialize from=dsv value="a,b,c\n1,2,3\n4,5,6" delimiter="," options=dsv.array];
:put (($rows->1)->"b");                   # => 5
:put (($rows->0)->"c");                   # => 3

# RULE 8.11: :deserialize options=dsv.plain — every line as array, NO header (7.18+)
:local m [:deserialize from=dsv value="a,b,c\n1,findme,3" delimiter="," options=dsv.plain];
:put (($m->0)->1);                        # => b          (row 0, col 1)
:put (($m->1)->1);                        # => findme

# RULE 8.12: dsv.remap is INVALID on :deserialize (parse error, not catchable!)
# :deserialize from=dsv value="a,b\n1,2" delimiter="," options=dsv.remap;
# => Script Error: syntax error (line N column NN)
# Use dsv.array for the symmetric inverse of :serialize ... options=dsv.remap.

# RULE 8.13: file-name= writes DSV directly to a file (mirrors json.rsc RULE 1.2)
:put [:serialize to=dsv value=({{a=1}}) delimiter="," options=dsv.remap file-name="out.csv"];
# => (empty string); file "out.csv" created on router filesystem

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
# │ JSON / DSV Opts  │ Purpose                                                   │
# ├──────────────────┼───────────────────────────────────────────────────────────┤
# │ json.pretty      │ Format with newlines and indentation                      │
# │ json.no-string-  │ Prevent "123"->123 conversion (CRITICAL!)                 │
# │   conversion     │                                                           │
# │ dsv.remap        │ 7.18+ :serialize only — array-of-dicts -> CSV w/ header   │
# │ dsv.wrap-strings │ 7.18+ :serialize — wrap string values in quotes (alone)   │
# │ dsv.array        │ 7.18+ :deserialize — header + rows -> array-of-dicts      │
# │ dsv.plain        │ 7.18+ :deserialize — every line -> array (no header)      │
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
# │ ✗ :serialize to=dsv REQUIRES delimiter= (no default, errors otherwise)      │
# │ ✗ dsv.remap is :serialize-only — INVALID on :deserialize (parse error!)     │
# │ ✗ dsv.remap demands array-of-dicts; flat scalar array errors "input not..." │
# │ ✗ dsv.remap+dsv.wrap-strings combo via (a,b) errors "unsupported options"   │
# │ ✓ Tab delimiter: delimiter="\t" or delimiter="\09" both work (7.18+)        │
# │ ✓ :deserialize default is COLUMN-oriented; use dsv.array for ROW-oriented   │
# └──────────────────────────────────────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+ baseline; 7.18+ DSV additions inline
# ══════════════════════════════════════════════════════════════════════════════
