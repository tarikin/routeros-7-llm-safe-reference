# RouterOS 7 Type System Reference
# VERIFIED on RouterOS 7.21+ baseline; 7.14-7.22 additions marked inline
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

# RULE 2.4: :tobool - behavior CHANGED in 7.22+
# Pre-7.22: accepts num only; any string returns nil.
# 7.22+:    accepts str / num / bool / ip / ip6 / id / array; only `time` returns nil.
:put [:tobool 1];                       # both: true
:put [:tobool 0];                       # both: false
# 7.22+ string casting (case-sensitive, exact match — NO whitespace tolerance):
:put [:tobool "yes"];                   # 7.22+: true   |  <7.22: nil
:put [:tobool "true"];                  # 7.22+: true   |  <7.22: nil
:put [:tobool "1"];                     # 7.22+: true   |  <7.22: nil
:put [:tobool "no"];                    # 7.22+: false  |  <7.22: nil
:put [:tobool "false"];                 # 7.22+: false  |  <7.22: nil
:put [:tobool "0"];                     # 7.22+: false  |  <7.22: nil
# 7.22+ ALL OTHER strings -> false (NOT nil). Case-sensitive, no synonyms:
:put [:tobool "YES"];                   # 7.22+: false  (NOT true — case strict)
:put [:tobool "True"];                  # 7.22+: false  (case strict)
:put [:tobool "on"];                    # 7.22+: false  (NOT a recognized synonym)
:put [:tobool "y"];                     # 7.22+: false  (no short forms)
:put [:tobool " yes"];                  # 7.22+: false  (whitespace strict)
:put [:tobool "garbage"];               # 7.22+: false
# 7.22+ non-string types (everything coerces except time):
:put [:tobool 192.168.1.1];             # 7.22+: true   (non-zero ip)
:put [:tobool 0.0.0.0];                 # 7.22+: false
:put [:tobool ::1];                     # 7.22+: true
:put [:tobool ({})];                    # 7.22+: false  (empty array)
:put [:tobool ({1;2})];                 # 7.22+: true
:put [:typeof [:tobool 1s]];            # nil — time is the ONLY non-coercible type

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

# Verified enum values on 7.23rc2 (testing):
#   to=    base32, base64, byte-array, hex, num, raw, url,
#          bit-array-lsb, bit-array-msb
#   from=  base32, base64, byte-array, hex, num, raw, url
#   transform= none, lc, uc, lcfirst, ucfirst, lf, crlf,
#              reverse, rot13, md5, sha512
# (sha1 / sha256 are NOT accepted; uppercase / lowercase / toupper / tolower
#  also NOT accepted — see RULE 3.6.)

# RULE 3.1: Base64 encoding/decoding
:put [:convert "abc" to=base64];        # => YWJj
:put [:convert from=base64 "YWJj"];     # => abc

# RULE 3.2: Hex encoding/decoding
:put [:convert "abc" to=hex];           # => 616263
:put [:convert from=hex "616263"];      # => abc

# RULE 3.3: Hash & text transforms (transform= argument)
:put [:convert "abcd" transform=reverse]; # => dcba
:put [:convert "hello" transform=rot13];  # => uryyb
:put [:len [:convert "test" transform=md5]];    # => 16 (raw bytes packed in str)
:put [:len [:convert "test" transform=sha512]]; # => 64 (raw bytes packed in str)
# To see hash output as printable hex, chain: transform=md5 to=hex
:put [:convert "test" transform=md5 to=hex];    # => 098f6bcd4621d373cade4e832627b4f6

# RULE 3.4: Combined operations (from + transform + to all chainable)
:put [:convert from=base64 "YWJjZA==" transform=reverse to=hex]; # => 64636261

# RULE 3.5: byte-array encoding (7.15+ added; 7.16+ enhanced)
# to=byte-array returns type "array" of num (each byte 0-255).
# Round-trip via from=byte-array reconstructs the original string.
:local ba [:convert "abc" to=byte-array];
:put [:typeof $ba];                     # => array  (NOT a dedicated byte-array type)
:put [:len $ba];                        # => 3
:put $ba;                               # => 97;98;99   (single line)
:put ($ba->0);                          # => 97         (typeof num)
:put [:convert $ba from=byte-array];    # => abc        (typeof str)
# UTF-8 multibyte: byte count, NOT codepoint count
:put [:len [:convert "Привет" to=byte-array]]; # => 12  (6 chars × 2 bytes)
# Coercion: any non-string input is :tostr'd first
:put [:len [:convert 192.168.1.1 to=byte-array]]; # => 11 (bytes of "192.168.1.1")
# from=byte-array silently returns "" on bad input (no error raised):
:put [:len [:convert "abc" from=byte-array]];     # => 0  (string input → empty)
:put [:len [:convert ({300;400}) from=byte-array]]; # => 0 (>255 → empty)

# RULE 3.6: Case transforms — transform=uc / lc / ucfirst / lcfirst / none (7.16+)
# CRITICAL NAMING: the values are uc / lc, NOT uppercase / lowercase.
# transform=uppercase, transform=lowercase, :tolower, :toupper all parse-fail.
:put [:convert "Hello World" transform=uc];      # => HELLO WORLD
:put [:convert "Hello World" transform=lc];      # => hello world
:put [:convert "hello" transform=ucfirst];       # => Hello   (first char only)
:put [:convert "HELLO" transform=lcfirst];       # => hELLO   (first char only)
:put [:convert "Hello" transform=none];          # => Hello   (identity / no-op)
# uc / lc are ASCII-ONLY — Cyrillic and other multibyte pass through unchanged:
:put [:convert "ПРИВЕТ" transform=lc];           # => ПРИВЕТ  (UTF-8 untouched)
:put [:convert "Hello Привет" transform=uc];     # => HELLO Привет
# Implicit :tostr coercion on non-string inputs:
:put [:convert true transform=uc];               # => TRUE
:put [:convert 192.168.1.1 transform=uc];        # => 192.168.1.1
# Multiple transform= keys → only the LAST wins (no chaining via repeats):
# :put [:convert "Hello" transform=md5 transform=uc];  # uc applied to md5 binary → garbled

# RULE 3.7: Line-ending transforms — transform=lf / crlf (7.17+)
# CRITICAL: these are TRANSFORMS, not destinations.
# to=lf, to=crlf, from=lf, from=crlf all PARSE-FAIL.
:put [:len [:convert "a\r\nb\r\nc" transform=lf]];  # => 5  (\r\n → \n)
:put [:len [:convert "a\nb\nc" transform=crlf]];    # => 7  (\n → \r\n)
# Bare \r is also normalized:
:put [:len [:convert "a\rb" transform=lf]];         # => 3  (\r → \n)
:put [:len [:convert "a\rb" transform=crlf]];       # => 4  (\r → \r\n)
# transform=crlf is idempotent on already-CRLF input (never doubles):
:put [:len [:convert "a\r\nb" transform=crlf]];     # => 4  (unchanged)
# No newline → unchanged; empty → empty
:put [:convert "abc" transform=lf];                 # => abc
:put [:len [:convert "" transform=lf]];             # => 0

# RULE 3.8: Numeric encoding — to=num / from=num (7.17+)
# CRITICAL: to=num returns type "str" (NOT num) — decimal of a big-endian
# 64-bit unsigned packing of the input bytes. Inputs > 8 bytes silently
# return "" (empty string), NO error raised. :onerror does NOT fire.
# VERIFIED REF-AUDIT-TYPES-CONVERT-NUM-9BYTES 2026-04-30 7.23rc2.
:put [:typeof [:convert "A" to=num]];               # => str  (NOT num!)
:put [:convert "A" to=num];                         # => 65         (= 0x41)
:put [:convert "AB" to=num];                        # => 16706      (= 0x4142)
:put [:convert "ABCD" to=num];                      # => 1094861636 (= 0x41424344)
:put [:convert "12345678" to=num];                  # => 4702394921427289928 (8-byte cap)
:put [:len [:convert "ABCDEFGHI" to=num]];          # => 0 (9 bytes silently → "")
:put [:len [:convert "ABCDEFGHIJ" to=num]];         # => 0 (10 bytes silently → "")
# Empty input is a degenerate case (single zero char "0", len=1; not numeric):
:put [:typeof [:convert "" to=num]];                # => str
:put [:len [:convert "" to=num]];                   # => 1
# from=num decodes integer back to byte string (big-endian):
:put [:convert 65 from=num];                        # => A
:put [:convert 6382179 from=num];                   # => abc       (= 0x616263)
:put [:convert 0x4142434445464748 from=num];        # => ABCDEFGH
# from=num accepts string-shaped numeric input:
:put [:convert "65" from=num];                      # => A
# Edge: from=num 0 produces a single NUL byte ("\0"), len=1 (not empty!)
:put [:len [:convert 0 from=num]];                  # => 1
# Edge: from=num on negative silently returns ""
:put [:len [:convert -1 from=num]];                 # => 0

# RULE 3.9: URL percent-encoding — to=url / from=url (7.15+)
# 7.15 added space, CR, LF coverage. ENCODES: space (%20), \r (%0d),
# \n (%0a), and most RFC 3986 reserved chars (gen/sub-delims).
# DOES NOT ENCODE: % itself, \t, 0x00-0x1F (except CR/LF), 0x7F (DEL),
# 0x80-0xFF (UTF-8 multibyte).
:put [:convert "a b c" to=url];                     # => a%20b%20c
:put [:convert "a\r\nb" to=url];                    # => a%0d%0ab
:put [:convert ":/?#[]@" to=url];                   # => %3a%2f%3f%23%5b%5d%40
:put [:convert "100%" to=url];                      # => 100%   (% NOT encoded!)
:put [:convert "a\tb" to=url];                      # => a\tb   (tab passthrough)
:put [:convert "Привет" to=url];                    # => Привет (UTF-8 passthrough)
# Encoder uses lowercase hex (%3a not %3A); decoder accepts either case.
# from=url silent failure on bad %-hex:
:put [:len [:convert "%ZZ" from=url]];              # => 0 (silent fail)
:put [:len [:convert "%2"  from=url]];              # => 0 (silent fail)
# '+' is NOT form-urlencoded — '+' decodes back to '+', not space:
:put [:convert "+" from=url];                       # => +

# RULE 3.10: :tolf / :tocrlf standalone commands (7.14+)
# Equivalent to :convert ... transform=lf / transform=crlf — exact byte-for-byte
# equality. Accept any input type via implicit :tostr.
:put ([:tolf "a\r\nb"] = [:convert "a\r\nb" transform=lf]);   # => true
:put ([:tocrlf "a\nb"] = [:convert "a\nb" transform=crlf]);   # => true
:put [:tolf 42];                       # => "42"   (non-string :tostr'd first)
:put [:len [:tolf]];                   # => 0      (no-arg returns ""; no error)
:local nilv;
:put [:len [:tolf $nilv]];             # => 0      (nil → "")

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

# RULE 6.6: ID values support full ordering on 7.22+
# Pre-7.22: id supports = and != only; <, >, <=, >= raise an error.
# 7.22+:    id supports <, >, <=, >= ordered by NUMERIC (hex) value of the *XX literal,
#           NOT by find-result order. Cross-namespace IDs compare in a single hex space:
#           interface *2 < route *80000001 is true.
:local ids [/interface find]
:local a ($ids->0); :local b ($ids->1)
:put ($a = $a);                         # both: true
:put ($a != $b);                        # both: true
:put ($a < $b);                         # 7.22+: bool. <7.22: error
:put ($a >= $a);                        # 7.22+: true (non-strict reflexive)
# Asymmetry — equality coerces str<->id, ordering does NOT:
:put ($a = [:tostr $a]);                # 7.22+: true (str coerced to id for equality)
# :put ($a < "*FFFFFFFF");              # ERROR: cannot compare if id is less than string

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      7. NETWORK TYPE OPERATIONS                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 7.1: IPv4 bitwise operations work — full set: & | ^ ~ << >>
:put (192.168.1.100 & 255.255.255.0);   # => 192.168.1.0   (typeof ip)
:put (192.168.1.0 | 0.0.0.255);         # => 192.168.1.255 (typeof ip)
:put (192.168.1.1 ^ 0.0.0.255);         # => 192.168.1.254 (typeof ip)
:put (~192.168.1.1);                    # => 63.87.254.254
:put (192.168.1.1 << 1);                # => 129.80.2.2
:put (192.168.1.1 >> 8);                # => 0.192.168.1
# /24 mask via shift:
:put ((192.168.1.45 >> 8) << 8);        # => 192.168.1.0

# RULE 7.2: IPv6 bitwise operations — << and >> added in 7.22+; & | ^ ~ also work
:put (::1 << 4);                        # => ::10           (typeof ip6)
:put (ffff:: >> 16);                    # => 0:ffff::
:put (::ff & ::1);                      # => ::1
:put (::1 | ::ff00);                    # => ::ff01
:put (::1 ^ ::ff);                      # => ::fe
:put (~::1);                            # => ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffe
# /64 prefix via shift idiom:
:put ((2001:db8:abcd:1234::1 >> 64) << 64);  # => 2001:db8:abcd:1234::

# RULE 7.3: IPv6 display quirk — lower 32 bits may print as IPv4-mapped form
:put (::1 << 16);                       # => ::0.1.0.0   (which is ::100:0)

# RULE 7.4: Shift overflow — standard wraparound, top/bottom bits discarded
:put (8000:: << 1);                     # => :: (high bit shifted out of 128-bit space)
:put (::1 << 128);                      # => :: (full-width shift zeroes the value)

# RULE 7.5: IP + number arithmetic WORKS!
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
# │ :tobool          │ 7.22+: str/all types coerce; <7.22: num only. time→nil    │
# │ :toarray         │ Uses delimiter=                                           │
# │ :totime          │ Parse time strings                                        │
# │ :toip6           │ Parse IPv6                                                │
# │ :tonsec          │ Time→nanoseconds (7.12+)                                  │
# │ :convert         │ base64/hex/transforms (7.12+)                             │
# │ :convert         │ to=byte-array (7.15+); to=base32, to=raw (7.15+)          │
# │ :convert         │ transform=uc/lc/ucfirst/lcfirst/none (7.16+) ASCII-only   │
# │ :convert         │ transform=lf/crlf line-end normalize (7.17+)              │
# │ :convert         │ to=num/from=num 64-bit BE pack, ≤8 bytes (7.17+)          │
# │ :convert         │ to=url adds space/CR/LF coverage (7.15+); % NOT encoded   │
# │ :tolf / :tocrlf  │ Standalone aliases of transform=lf / crlf (7.14+)         │
# └──────────────────┴───────────────────────────────────────────────────────────┘
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ LLM PITFALLS                                                                 │
# ├──────────────────────────────────────────────────────────────────────────────┤
# │ ✗ [:tobool "yes"] returns nil on <7.22; bool true on 7.22+ (case-strict)     │
# │ ✗ [:tobool "YES"] / "True" / " yes" / "on" / "y" all return false on 7.22+   │
# │ ✗ [:tobool 1s] returns nil — time is the ONLY non-coercible type on 7.22+    │
# │ ✗ [:tonum "23.8"] returns nil (no floats)                                    │
# │ ✗ [:typeof function] returns "array" (standard) or "code" (parsed)           │
# │ ✗ [:typeof []] returns "nil", NOT "array"                                    │
# │ ✗ "abc" < "xyz" is ERROR (string comparison only = and !=)                   │
# │ ✗ id < "string" ERRORS (7.22+ ordering not coercive); id = "string" works    │
# │ ✗ Integer overflow wraps silently to negative                                │
# │ ✗ transform=uppercase / lowercase / toupper / tolower DO NOT EXIST           │
# │   use transform=uc / lc / ucfirst / lcfirst (7.16+); ASCII-only              │
# │ ✗ :tolower / :toupper standalone DO NOT EXIST (use :convert transform=lc/uc) │
# │ ✗ to=lf / to=crlf / from=lf / from=crlf PARSE-FAIL — use transform=lf/crlf   │
# │ ✗ [:convert ... to=num] returns str (NOT num); >8 bytes silently → ""        │
# │ ✗ [:convert 0 from=num] returns "\0" (single NUL byte, len=1) NOT empty      │
# │ ✗ [:convert ("len=" . $byteArray)] iterates: prints "len=97","len=98"...     │
# │   use [:tostr $ba] inside concat, or :put $ba (no concat) for one line       │
# │ ✗ to=url leaves %, \t, 0x80-0xFF unencoded; from=url silent "" on bad %-hex  │
# │ ✗ [:typeof [:convert "x" to=byte-array]] = "array" (no dedicated type)       │
# │ ✗ [:convert "abc" from=byte-array] silently returns "" (no error on bad in)  │
# │ ✓ "5" + 10 = 15 (string auto-coerced in arithmetic)                          │
# │ ✓ 192.168.1.1 + 1 = 192.168.1.2 (IP arithmetic works!)                       │
# │ ✓ ::1 << 4 = ::10 (IPv6 bit-shift on 7.22+; full bitwise set: & | ^ ~ << >>) │
# │ ✓ ($idA < $idB) on 7.22+ = bool, ordered by hex value of *XX literal         │
# │ ✓ [:tolf $s] = [:convert $s transform=lf] (7.14+ standalone alias)           │
# └──────────────────────────────────────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+ baseline; 7.14-7.22 additions inline
# ══════════════════════════════════════════════════════════════════════════════
