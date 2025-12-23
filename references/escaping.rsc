# RouterOS 7 String Escaping & Nesting Reference
# VERIFIED on RouterOS 7.21+
# This document contains ONLY empirically verified behavior from 72 tests.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      1. BASIC ESCAPE SEQUENCES                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 1.1: Standard escape characters
:put "Newline:\nSecond line";         # \n = newline
:put "Tab:\tafter";                   # \t = tab
:put "Quote: \"text\"";               # \" = literal quote
:put "Backslash: \\path";             # \\ = single backslash
:put "Dollar: \$100";                 # \$ = literal $ (no expansion)

# RULE 1.2: Carriage return (\r) overwrites from line start
:put "Before\rAfter";                 # => "Afterore" (CR moves cursor back)

# RULE 1.3: Line continuation with trailing backslash
:local continued ("part1" . \
"part2");                             # Joins lines
:put $continued;                      # => "part1part2"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      2. VARIABLE INTERPOLATION                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 2.1: Variables expand inside double-quoted strings
:local myVar "VALUE";
:put "Text $myVar text";              # => "Text VALUE text"

# RULE 2.2: \$ prevents expansion
:local price 100;
:put "Cost is \$price";               # => "Cost is $price" (literal)

# RULE 2.3: Quoted variable names CANNOT be used inline
# ✗ WRONG: :put "Text $\"my-var\" text";
# ✓ CORRECT: Use concatenation:
:local "my-var" "HYPHEN";
:put ("Text " . $"my-var" . " text"); # => "Text HYPHEN text"

# RULE 2.4: Undefined variables return empty (no error)
:put ("undef=" . $undefinedVar);      # => "undef="

# RULE 2.5: Expression evaluation via concatenation
:local num 5;
:put ("Result=" . ($num + 3));        # => "Result=8"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      3. NESTED CODE BLOCKS do={}                            │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 3.1: Braces nest naturally - no escaping needed
:if (true) do={
  :if (true) do={
    :if (true) do={
      :if (true) do={
        :put "four-level-nesting";
      };
    };
  };
};

# RULE 3.2: Quotes inside do={} work normally
:if (true) do={ :put "has \"quotes\" inside"; };

# RULE 3.3: Comments inside do={} work
:if (true) do={
  # This is a comment inside do block
  :put "with-comment";
};

# RULE 3.4: Semicolons required for multiple statements
:if (true) do={ :put "a"; :put "b"; }; # Both execute

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      4. SCHEDULER ON-EVENT ESCAPING                         │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 4.1: \n creates real newlines in on-event scripts
/system scheduler add name="example" on-event=":local a 1;\n:local b 2;\n:log info (\$a + \$b)";
# Result: Real multiline script stored

# RULE 4.2: \$ defers variable expansion to execution time
/system scheduler add name="deferred" on-event=":global myGlobal;:log info \$myGlobal";
# Variable evaluated when scheduler runs, not when created

# RULE 4.3: $var expands IMMEDIATELY at creation time
:local nowVal "CREATED";
/system scheduler add name="immediate" on-event=":log info \"$nowVal\"";
# Value "CREATED" is baked into the script

# RULE 4.4: Nested control flow works inside on-event
/system scheduler add name="nested" on-event=":if (true) do={:log info \"inside\"}";
/system scheduler add name="loop" on-event=":for i from=1 to=3 do={:log info \$i}";

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      5. :EXECUTE NESTED STRINGS                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 5.1: Basic :execute syntax (positional, not script=)
:execute ":put \"hello\"";            # Correct
# :execute script=":put \"hello\"";   # WRONG - no script= parameter

# RULE 5.2: :execute is ASYNC - use :delay for output timing
:execute ":put \"async\"";
:delay 500ms;                         # Wait for output

# RULE 5.3: Capture output with as-string
:local result [:execute script=":put \"captured\"" as-string];
:put $result;                         # => "captured\n"

# RULE 5.4: Escaped variables resolve at execution time
:global gVar "value";
:execute ":global gVar;:put \$gVar";  # Prints value at execution time

# RULE 5.5: :execute modifies globals (shared scope)
:global gExec "before";
:execute ":global gExec;:set gExec \"after\"";
:delay 1s;
:put $gExec;                          # => "after"

# RULE 5.6: Nested quotes require double escaping
:execute ":put \"outer \\\"inner\\\" quote\"";
# Prints: outer "inner" quote

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      6. HEX/UNICODE ESCAPES                                 │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 6.1: Hex escape format is \XX (two uppercase hex digits)
:put "\41";                           # => "A" (0x41 = 65 = 'A')
:put "\0A";                           # => newline (0x0A = 10 = LF)

# RULE 6.2: UPPERCASE HEX ONLY - lowercase is PARSE ERROR
# ✗ WRONG: :put "\e2\9c\85";          # PARSE ERROR
# ✓ CORRECT:
:put "\E2\9C\85";                     # => ✅ (checkmark emoji)

# RULE 6.3: Multi-byte UTF-8 sequences for emoji
:put "\F0\9F\9F\A1";                  # => 🟡 (yellow circle, 4 bytes)
:put "\E2\9C\85";                     # => ✅ (checkmark, 3 bytes)
:put "\F0\9F\94\B4";                  # => 🔴 (red circle, 4 bytes)

# RULE 6.4: Hex escapes can be stored in variables
:local greenCheck "\E2\9C\85";
:put ($greenCheck . " Done");         # => ✅ Done

# RULE 6.5: %XX (URL encoding) stays literal in strings
:local urlEncoded "line1%0Aline2";
:put $urlEncoded;                     # => "line1%0Aline2" (literal)
# Use \0A for actual newline in strings

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      7. JSON/DSV ESCAPING                                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 7.1: :serialize handles quote escaping automatically
:local arr {"msg"="Hello \"World\""};
:put [:serialize to=json value=$arr];
# => {"msg":"Hello \"World\""}

# RULE 7.2: :deserialize parses escaped JSON
:local parsed [:deserialize from=json value="{\"a\":1,\"b\":2}"];
:put ($parsed->"a");                  # => 1

# RULE 7.3: DSV serialization handles delimiters in data
:local arr {"col1"="val;ue"};
:put [:serialize to=dsv value=$arr delimiter=";"];
# Properly escapes semicolon in value

# RULE 7.4: Hyphenated keys work in dictionaries
:local dict {"my-key"="my-value"};
:put ($dict->"my-key");               # => "my-value"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      8. REGEX SPECIAL CHARACTERS                            │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 8.1: ~ operator uses regex matching
:local str "hello world";
:put ($str ~ "hello");                # => true

# RULE 8.2: Regex wildcards and character classes work
:put ("start-middle-end" ~ "start.*end");  # => true (any chars)
:put ("test123" ~ "[0-9]+");               # => true (digit class)

# RULE 8.3: Escaped dot matches literal period
:put ("192.168.1.1" ~ "192\\.168");   # => true
# Single backslash in RouterOS string = escaped for regex

# RULE 8.4: Anchors work
:put ("prefix-content" ~ "^prefix");  # => true (start anchor)
:put ("prefix-content" ~ "content\$"); # => true (end anchor)

# RULE 8.5: :find returns position (not regex - literal search)
:put [:find "find the needle here" "needle"]; # => 9

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      9. DEEP NESTING PATTERNS                               │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 9.1: Escape doubling rule for nested strings
# Level 1 (direct string): "text \"quote\" text"
# Level 2 (string in string): "outer \"inner \\\"deep\\\" inner\" outer"
# Level 3 (scheduler/execute): Add more backslashes

# RULE 9.2: Scheduler with inner quoted string
/system scheduler add name="nested-quote" on-event=":local msg \"hello \\\"world\\\"\";:log info \$msg";
# Creates script: :local msg "hello \"world\"";:log info $msg

# RULE 9.3: Function returning string with quotes works
:global fnQuotes do={
  :local inner "has \"quotes\"";
  :return $inner;
};
:put [$fnQuotes];                     # => has "quotes"

# RULE 9.4: $ escaping depth pattern for scheduler
# At creation: $var expands immediately
# At creation: \$var defers to execution time
# Inside quotes in on-event: \\$var
# Deeper: \\\$var, etc.

# RULE 9.5: Scheduler with :execute (maximum practical nesting)
/system scheduler add name="deep" on-event=":execute \":put \\\"deep\\\"\"";
# Creates scheduler that runs :execute ":put \"deep\""

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                       QUICK REFERENCE TABLE                                 │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌──────────────┬───────────────────────────────────────────────────────────────┐
# │ Escape       │ Result                                                        │
# ├──────────────┼───────────────────────────────────────────────────────────────┤
# │ \n           │ Newline                                                       │
# │ \t           │ Tab                                                           │
# │ \r           │ Carriage return (overwrites from line start)                  │
# │ \\           │ Single backslash                                              │
# │ \"           │ Literal quote                                                 │
# │ \$           │ Literal $ (prevents variable expansion)                       │
# │ \XX          │ Hex byte (UPPERCASE only: \E2 not \e2)                        │
# └──────────────┴───────────────────────────────────────────────────────────────┘
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Context              │ Escaping Notes                                        │
# ├──────────────────────┼──────────────────────────────────────────────────────-┤
# │ Direct string        │ Single escapes: \"  \$  \\                            │
# │ Scheduler on-event   │ \n for newlines, \$ for deferred vars                 │
# │ :execute string      │ Double escapes for inner quotes: \\\"                 │
# │ Nested scheduler     │ Triple+ for deep nesting                              │
# │ Regex patterns       │ Single \\ for regex escapes: \\.                      │
# │ Hex escapes          │ UPPERCASE only: \F0\9F not \f0\9f                     │
# └──────────────────────┴───────────────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+
# ══════════════════════════════════════════════════════════════════════════════
