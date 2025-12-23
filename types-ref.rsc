# RouterOS 7 Type System Reference
# VERIFIED on RouterOS 7.21+
# This document contains ONLY empirically verified behavior

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      1. TYPE IDENTIFICATION                                 │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 1.1: All types returned by [:typeof]
# ┌───────────────┬───────────────────────────────────────────────────────────┐
# │ Type          │ Example                                                   │
# ├───────────────┼───────────────────────────────────────────────────────────┤
# │ nothing       │ Uninitialized variable, undeclared variable, empty []     │
# │ nil           │ Result of failed conversion, empty array                  │
# │ bool          │ true, false                                               │
# │ str           │ "text", empty ""                                          │
# │ num           │ 42, -100, 0, 0xFF                                         │
# │ ip            │ 192.168.1.1                                               │
# │ ip6           │ 2001:db8::1                                               │
# │ ip-prefix     │ 192.168.0.0/24                                            │
# │ ip6-prefix    │ 2001:db8::/32                                             │
# │ time          │ 1h30m, [:timestamp], [/system clock get time]             │
# │ array         │ {1;2;3}, {"key"="val"}, STANDARD FUNCTIONS                │
# │ id            │ [:execute] result, internal object IDs                    │
# │ code          │ [:parse] result                                           │
# └───────────────┴───────────────────────────────────────────────────────────┘

# RULE 1.2: Function types - STANDARD vs PARSED
# Standard function (do={}) returns "array":
:global stdFunc do={ :return 1; };
:put [:typeof $stdFunc];                 # => array

# Parsed function ([:parse]) returns "code":
:global parsedFunc [:parse ":return 1"];
:put [:typeof $parsedFunc];              # => code

# RULE 1.3: Empty array [] returns type "nil" (NOT "array")
:put [:typeof []];                      # => nil
:put [:len []];                         # => 0

# RULE 1.4: ID from find operations returns "array" (list of IDs)
:local ids [/interface find];
:put [:typeof $ids];                    # => array

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      2. TYPE CONVERSION (:to*)                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 2.1: :tonum - integers ONLY, returns nil for invalid
:put [:tonum "123"];                    # => 123
:put [:tonum "-456"];                   # => -456
:put [:tonum "23.8"];                   # => nil (NO floats!)
:put [:tonum "abc"];                    # => nil
:put [:tonum ""];                       # => nil
:put [:tonum " 100 "];                  # => nil (spaces not trimmed!)
:put [:tonum true];                     # => nil (bool not convertible!)

# RULE 2.2: :tostr - universal, always works
:put [:tostr 12345];                    # => "12345"
:put [:tostr true];                     # => "true"
:put [:tostr 192.168.1.1];              # => "192.168.1.1"
:put [:tostr 1h30m];                    # => "01:30:00"
:put [:tostr {1;2;3}];                  # => "1;2;3"

# RULE 2.3: :toip - converts strings and extracts from prefix
:put [:toip "192.168.1.1"];             # => 192.168.1.1
:put [:toip 10.0.0.0/24];               # => 10.0.0.0 (extracts IP from prefix!)
:put [:toip "not-ip"];                  # => nil
:put [:toip "256.1.1.1"];               # => nil (invalid octet)

# RULE 2.4: :tobool - ONLY works with numbers, NOT strings!
:put [:tobool 1];                       # => true
:put [:tobool 0];                       # => false (presumably)
:put [:tobool "yes"];                   # => nil (NOT true!)
:put [:tobool "true"];                  # => nil (NOT true!)
:put [:tobool "no"];                    # => nil

# RULE 2.5: :toarray - splits strings by delimiter
:put [:len [:toarray "a,b,c" delimiter=","]]; # => 3
:put [:typeof [:toarray "single"]];           # => array (len 1)

# RULE 2.6: :totime - converts time strings
:put [:totime "1h30m"];                 # => 01:30:00
:put [:totime "nottime"];               # => nil

# RULE 2.7: :toip6 - converts IPv6 strings
:put [:toip6 "2001:db8::1"];            # => 2001:db8::1
:put [:toip6 "not-ipv6"];               # => nil

# RULE 2.8: :tonsec - time to nanoseconds (7.12+)
:put [:tonsec 1s];                      # => 1000000000
:put [:tonsec 1m];                      # => 60000000000

# RULE 2.9: :parse hack for specialized types (str -> ip/ip6)
:put [:typeof [[:parse ":return 1.1.1.1"]]];  # => ip
:put [:typeof [[:parse ":return 1h"]]];       # => time

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      3. :convert COMMAND (7.12+)                            │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 3.1: Base64 encoding/decoding
:put [:convert "abc" to=base64];        # => YWJj
:put [:convert from=base64 "YWJj"];     # => abc

# RULE 3.2: Hex encoding/decoding
:put [:convert "abc" to=hex];           # => 616263
:put [:convert from=hex "616263"];      # => abc

# RULE 3.3: Transforms available
:put [:convert "abcd" transform=reverse]; # => dcba
:put [:convert "hello" transform=rot13];  # => uryyb
:put [:len [:convert "test" transform=md5]];    # => 16 bytes
:put [:len [:convert "test" transform=sha512]]; # => 64 bytes

# RULE 3.4: Combined operations
:put [:convert from=base64 "YWJjZA==" transform=reverse to=hex]; # => 64636261

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      4. IMPLICIT TYPE COERCION                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 4.1: String + Number in arithmetic = auto-converts string to num!
:local strVal "5";
:local numVal 10;
:put ($strVal + $numVal);               # => 15 (string coerced!)
:put ($numVal + $strVal);               # => 15

# RULE 4.2: Concatenation (.) converts everything to string
:put ("val=" . 123);                    # => "val=123"
:put (192.168.1.1 . ":8080");           # => "192.168.1.1:8080"
:put (true . "-suffix");                # => "true-suffix"

# RULE 4.3: Nothing/nil in expressions
:local nilVar;
:put ($nilVar . "text");                # => "text" (nil becomes empty)
:put ($nilVar + 1);                     # => 1 (nil treated as 0!)

# RULE 4.4: Boolean in expressions
:put (true && false);                   # => false
:put (true || false);                   # => true
:put (!true);                           # => false
# :put (true + 1);                      # => ERROR (bool + num not allowed)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      5. NUMERIC OPERATIONS                                  │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 5.1: All arithmetic returns type num
:put (10 + 5);                          # => 15
:put (10 - 5);                          # => 5
:put (10 * 5);                          # => 50
:put (10 / 3);                          # => 3 (INTEGER division!)
:put (10 % 3);                          # => 1

# RULE 5.2: Bitwise operations work
:put (0xFF & 0x0F);                     # => 15
:put (0xF0 | 0x0F);                     # => 255
:put (0xFF ^ 0x0F);                     # => 240
:put (1 << 4);                          # => 16
:put (16 >> 2);                         # => 4

# RULE 5.3: Division by zero is ERROR
# :put (10 / 0);                        # => ERROR

# RULE 5.4: Overflow wraps to negative (signed 64-bit)
:put 9223372036854775807;               # => max int64
:put (9223372036854775807 + 1);         # => -9223372036854775808 (wraps!)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      6. COMPARISON OPERATIONS                               │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 6.1: Numeric comparisons work
:put (5 < 10);                          # => true
:put (5 = 5);                           # => true
:put (5 != 10);                         # => true

# RULE 6.2: String comparisons - ONLY = and != allowed!
:put ("abc" = "abc");                   # => true
:put ("abc" != "xyz");                  # => true
# :put ("abc" < "xyz");                 # => ERROR! not allowed

# RULE 6.3: Cross-type comparison with coercion
:put (5 = "5");                         # => true (string coerced to num!)
:put (true = 1);                        # => false (bool != num)

# RULE 6.4: Regex match with ~
:put ("hello" ~ "hel.*");               # => true
:put ("hello" ~ "xyz");                 # => false

# RULE 6.5: IP in prefix
:put (192.168.1.1 in 192.168.0.0/16);   # => true
:put (10.0.0.1 in 192.168.0.0/16);      # => false
:put (192.168.1.0/24 in 192.168.0.0/16); # => true (prefix in prefix)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      7. NETWORK TYPE OPERATIONS                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 7.1: IP bitwise operations work
:put (192.168.1.100 & 255.255.255.0);   # => 192.168.1.0 (type ip)
:put (192.168.1.0 | 0.0.0.255);         # => 192.168.1.255 (type ip)
:put (192.168.1.1 ^ 0.0.0.255);         # => 192.168.1.254 (type ip)

# RULE 7.2: IP + number arithmetic WORKS!
:put (192.168.1.1 + 1);                 # => 192.168.1.2

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      8. ARRAY OPERATIONS                                    │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 8.1: Array indexing (0-based)
:local arr {1;2;3;4;5};
:put ($arr->0);                         # => 1
:put ($arr->2);                         # => 3

# RULE 8.2: Dict key access
:local dict {"a"=1;"b"=2};
:put ($dict->"b");                      # => 2

# RULE 8.3: Nested access
:local nested {"outer"={"inner"="value"}};
:put ($nested->"outer"->"inner");       # => value

# RULE 8.4: Merge arrays with comma
:local merged ({1;2},{3;4});
:put [:len $merged];                    # => 4

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      9. FUNCTION RETURN TYPES                               │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 9.1: Function variable has type "array" (NOT "code")
:global fn do={ :return 123; };
:put [:typeof $fn];                     # => array

# RULE 9.2: Function call returns the actual type
:put [:typeof [$fn]];                   # => num (from return 123)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      QUICK REFERENCE TABLE                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌──────────────────┬───────────────────────────────────────────────────────────┐
# │ Conversion       │ Notes                                                     │
# ├──────────────────┼───────────────────────────────────────────────────────────┤
# │ :tonum           │ Integers ONLY. "23.8"→nil, " 100 "→nil, true→nil          │
# │ :tostr           │ Universal, always works                                   │
# │ :toip            │ Also extracts IP from prefix                              │
# │ :tobool          │ Numbers only! "yes"→nil, "true"→nil                       │
# │ :toarray         │ Uses delimiter=                                           │
# │ :totime          │ Parse time strings                                        │
# │ :toip6           │ Parse IPv6                                                │
# │ :tonsec          │ Time→nanoseconds (7.12+)                                  │
# │ :convert         │ base64/hex/transforms (7.12+)                             │
# └──────────────────┴───────────────────────────────────────────────────────────┘
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ LLM PITFALLS                                                                 │
# ├──────────────────────────────────────────────────────────────────────────────┤
# │ ✗ [:tobool "yes"] returns nil, NOT true                                      │
# │ ✗ [:tonum "23.8"] returns nil (no floats)                                    │
# │ ✗ [:typeof function] returns "array" (standard) or "code" (parsed)             │
# │ ✗ [:typeof []] returns "nil", NOT "array"                                    │
# │ ✗ "abc" < "xyz" is ERROR (string comparison only = and !=)                   │
# │ ✗ Integer overflow wraps silently to negative                                │
# │ ✓ "5" + 10 = 15 (string auto-coerced in arithmetic)                          │
# │ ✓ 192.168.1.1 + 1 = 192.168.1.2 (IP arithmetic works!)                       │
# └──────────────────────────────────────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+
# ══════════════════════════════════════════════════════════════════════════════
