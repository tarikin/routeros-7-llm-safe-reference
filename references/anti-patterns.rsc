# RouterOS 7 LLM Anti-Patterns Reference
# VERIFIED PITFALLS: Errors discovered through empirical testing on RouterOS 7.21+

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 1. VARIABLE NAMING - SPECIAL CHARS REQUIRE QUOTES EVERYWHERE               │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :local my-var "test";     # PARSE ERROR at hyphen
# :local my_var "test";     # PARSE ERROR at underscore
# :put $my-var;             # PARSE ERROR

# ✓ CORRECT:
:local "my-var" "test";
:put $"my-var";
:local "my_var" "test2";
:put $"my_var";

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 2. :set ON UNDECLARED VARIABLE = PARSE-TIME ERROR (NOT RUNTIME)            │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Cannot catch with :onerror, script won't even compile:
# :set undeclaredVar "value";

# ✓ CORRECT - Must declare first:
:local myVar;
:set myVar "value";

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 3. FUNCTIONS CANNOT ACCESS OUTER :local - NO CLOSURES                      │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - PARSE ERROR, not runtime error:
# :local outer "value";
# :global fn do={ :put $outer; };  # FAILS: outer not declared in function

# ✓ CORRECT - Use :global and re-declare inside function:
:global gOuter "value";
:global fn do={ :global gOuter; :put $gOuter; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 4. CANNOT RETURN FUNCTIONS / NO HIGHER-ORDER FUNCTIONS                     │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - PARSE ERROR:
# :global makeAdder do={
#   :return do={ :return ($1 + $2); };  # FAILS
# };

# ✓ NO WORKAROUND - RouterOS does not support closures or returning code blocks

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 5. :onerror BLOCKS SHOULD BE SINGLE-LINE                                   │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ PROBLEMATIC - May cause parse errors:
# :onerror e in={
#   :put "line1";
#   :put "line2";
# } do={
#   :put "error";
# };

# ✓ SAFER - Single line:
:onerror e in={ :put "try"; } do={ :put "catch"; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 6. :execute STDOUT IS NOT OBSERVABLE WITHOUT as-string — see #13            │
# └─────────────────────────────────────────────────────────────────────────────┘
# All three :execute source forms are accepted on 7.23rc2:
#   (a) :execute "<src>"          (positional, fire-and-forget)
#   (b) :execute script="<src>"   (named, fire-and-forget)
#   (c) :execute script={ <blk> } (block, fire-and-forget)
# The 'WRONG' framing in older docs was incorrect: bare script= parses and
# executes. The pitfall is observability — none of (a)/(b)/(c) propagate the
# inner :put output back to the caller. To capture stdout, use as-string (#13).
# ✗ WRONG assumption (that bare named form returns observable output):
# :execute script=":put hello";   # parses + runs, but caller sees nothing

# ✓ CORRECT (capture output explicitly):
:local r [:execute script=":put hello" as-string];
:put $r;                          # => hello\n
# VERIFIED REF-AUDIT-EXEC-SCRIPT-PARAM-ASYM 2026-04-30 7.23rc2

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 7. RECURSIVE FUNCTIONS NEED :global SELF-REFERENCE                         │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - fn not visible inside itself without re-declaration:
# :global fn do={ :return [$fn ($1 - 1)]; };

# ✓ CORRECT - Must re-declare inside:
:global fnRecurse do={
  :global fnRecurse;
  :if ($1 <= 0) do={ :return "done"; };
  :return [$fnRecurse ($1 - 1)];
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 8. ACCESSING OUT-OF-SCOPE VARIABLE RETURNS EMPTY (NO ERROR)                │
# └─────────────────────────────────────────────────────────────────────────────┘
# This is SILENT - no runtime error, just empty value:
{ :local x "exists"; }
:put $x;  # => empty string, NO ERROR
:put [:typeof $x];  # => "nothing"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 9. LOOP ITERATORS VANISH AFTER LOOP                                        │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG ASSUMPTION - Iterator persists:
# :for i from=1 to=3 do={ };
# :put $i;  # WRONG: returns empty, not 3

# ✓ CORRECT - Copy to outer if needed:
:local lastI;
:for i from=1 to=3 do={ :set lastI $i; };
:put $lastI;  # => 3

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 10. :global INSIDE BLOCK NEEDS RE-DECLARATION OUTSIDE                      │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ INCOMPLETE:
# { :global gInner "value"; }
# :put $gInner;  # Returns empty!

# ✓ CORRECT - Re-declare to access:
{ :global gInner "value"; }
:global gInner;
:put $gInner;  # => "value"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         CONDENSED CHEAT SHEET                               │
# └─────────────────────────────────────────────────────────────────────────────┘
# PARSE-TIME ERRORS (script won't compile):
#   - :set without prior :global/:local
#   - Accessing outer :local from function
#   - Returning do={} blocks
#   - Unquoted special chars in var names (-, _)
#   - Lowercase hex escapes (\e2 instead of \E2)
#
# SILENT FAILURES (no error, just empty):
#   - Out-of-scope variable access
#   - Undeclared variable in :put
#   - Loop iterator after loop
#   - :global without re-declaration outside block
#
# SYNTAX TRAPS:
#   - :execute "script" not :execute script="script"
#   - Multiline :onerror may fail
#   - Recursive fn needs :global self-ref inside body

# ═══════════════════════════════════════════════════════════════════════════════
#                    ESCAPING ANTI-PATTERNS (from 72-test verification)
# ═══════════════════════════════════════════════════════════════════════════════

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 11. LOWERCASE HEX ESCAPES = PARSE ERROR                                     │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :put "\e2\9c\85";           # PARSE ERROR - lowercase hex

# ✓ CORRECT - UPPERCASE hex only:
:put "\E2\9C\85";             # => ✅

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 12. $"quoted-var" CANNOT BE USED INLINE IN STRINGS                          │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Syntax error:
# :put "Text $\"my-var\" text";

# ✓ CORRECT - Use concatenation:
:local "my-var" "HYPHEN";
:put ("Text " . $"my-var" . " text");

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 13. :execute SOURCE FORMS — positional / script= / script={...} — see #6    │
# └─────────────────────────────────────────────────────────────────────────────┘
# All three forms parse + execute on 7.23rc2 (REF-AUDIT-EXEC-SCRIPT-PARAM-ASYM
# 2026-04-30):
:execute ":put test";                            # (a) positional, detached
:execute script=":put test";                     # (b) named, detached — equivalent to (a)
:execute script={ :put "test" };                 # (c) block form, detached
# The output of (a)/(b)/(c) is NOT visible to the caller (detached job).
# Use as-string to capture stdout as a str return value:
:local result [:execute script=":put \"test\"" as-string];
:put $result;                                    # => test\n

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 14. SCHEDULER $var vs \$var EXPANSION TIMING                                │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ COMMON MISTAKE - Variable baked in at creation:
:local myVal "at-creation";
# on-event=":log info \"$myVal\"" => expands NOW, not at runtime

# ✓ CORRECT - Use \$ for runtime expansion:
# on-event=":global myGlobal;:log info \$myGlobal"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 15. NESTED QUOTE ESCAPE DEPTH                                               │
# └─────────────────────────────────────────────────────────────────────────────┘
# Level 1: "text \"quote\" text"
# Level 2 (scheduler): ":put \"inner \\\"deep\\\" inner\""
# Level 3 (:execute in scheduler): add more backslashes

# ✗ COMMON: Forgetting to double escapes at each level
# ✓ PATTERN: Each nesting level doubles the backslashes

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 16. :execute IS ASYNC - OUTPUT NOT IMMEDIATE                                │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Expecting synchronous output:
# :execute ":put \"hello\"";
# :put "after";  # Runs before execute completes!

# ✓ CORRECT - Add delay or use as-string:
:execute ":put \"hello\"";
:delay 500ms;
:put "after";

# ═══════════════════════════════════════════════════════════════════════════════
#                    TYPE SYSTEM ANTI-PATTERNS (from 155-test verification)
# ═══════════════════════════════════════════════════════════════════════════════

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 17. :tobool BEHAVIOR DIFFERS BY VERSION (7.22+ accepts strings)             │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG ASSUMPTION (pre-7.22 stale advice):
# "[:tobool \"yes\"] returns nil; use only numeric input"
# That was true on <7.22 ONLY. On 7.22+ strings DO coerce, but with strict rules.
#
# ✗ WRONG (7.22+) — assuming string casting is forgiving:
# :if ([:tobool "YES"]) do={ ... }     # false (case-sensitive!)
# :if ([:tobool " yes"]) do={ ... }    # false (whitespace not trimmed!)
# :if ([:tobool "y"]) do={ ... }       # false (no short forms!)
# :if ([:tobool "on"]) do={ ... }      # false (not a recognized token!)

# ✓ CORRECT — version-portable input handling
:put [:tobool 1];                     # both versions: true
:put [:tobool 0];                     # both versions: false
# 7.22+ accepts EXACTLY these strings: "yes" "no" "true" "false" "1" "0"
# All others coerce to false (NOT nil) on 7.22+; pre-7.22 they returned nil.
:put [:tobool "yes"];                 # 7.22+: true   |  <7.22: nil
# To support both versions, normalize before casting:
:local s "Yes"; :set s [:convert $s transform=lc];
:put [:tobool $s];                    # 7.22+: true
# CRITICAL: time is the ONLY type that returns nil on 7.22+
:put [:typeof [:tobool 1s]];          # nil — use [:tonsec $t] > 0 instead
# VERIFIED REF-AUDIT-TOBOOL-CASESTRICT-7.22 2026-04-30 7.23rc2

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 18. :tonum DOES NOT SUPPORT FLOATS OR WHITESPACE                            │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :local n [:tonum "23.8"];           # => nil (not 23!)
# :local m [:tonum " 100 "];          # => nil (spaces!)

# ✓ CORRECT - Clean input first:
:local clean "100";
:put [:tonum $clean];                 # => 100

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 19. [:typeof function] RETURNS "array" — :parse RETURNS "code" — see #50    │
# └─────────────────────────────────────────────────────────────────────────────┘
# Two distinct invocable types coexist on 7.23rc2:
#   do={ ... }   literal              → :typeof = "array"
#   [:parse "..." ]                   → :typeof = "code" (see #50)
# Both invoke the same way: [$f] / [$f arg=...]. #19 and #50 are complementary,
# not contradictory.
# ✗ WRONG assumption (do={} is NEVER "code"):
# :if ([:typeof $fn] = "code") do={ ... }  # never true for do={...} fn literal

# ✓ CORRECT:
:global fn do={ :return 1; };
:if ([:typeof $fn] = "array") do={ :put "is-do-fn"; };
# VERIFIED REF-AUDIT-PARSE-TYPEOF 2026-04-30 7.23rc2

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 20. EMPTY ARRAY [] RETURNS TYPE "nil", NOT "array"                          │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :if ([:typeof $arr] = "array") do={ ... }  # Fails for empty!

# ✓ CORRECT - Check length instead:
:local arr [];
:if ([:len $arr] = 0) do={ :put "empty"; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 21. STRING COMPARISON < > NOT ALLOWED                                       │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :if ("abc" < "xyz") do={ ... }      # RUNTIME ERROR!

# ✓ CORRECT - Only = and != work for strings:
:if ("abc" = "abc") do={ :put "equal"; };
:if ("abc" != "xyz") do={ :put "different"; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 22. INTEGER OVERFLOW WRAPS SILENTLY                                         │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ DANGEROUS:
# :local big (9223372036854775807 + 1);  # => -9223372036854775808 (wrapped!)

# ✓ CORRECT - Check bounds if needed:
:local maxInt 9223372036854775807;
# No overflow protection - be careful with large numbers!

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 23. STRING + NUMBER AUTO-COERCES (SURPRISING!)                               │
# └─────────────────────────────────────────────────────────────────────────────┘
# This is NOT an error - it works, but may surprise:
:local strVal "5";
:put ($strVal + 10);                  # => 15 (string coerced to num!)

# Be explicit if you want concatenation:
:put ($strVal . 10);                  # => "510"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 24. IP ARITHMETIC WORKS (OFTEN UNKNOWN)                                     │
# └─────────────────────────────────────────────────────────────────────────────┘
# This actually WORKS - not an error:
:put (192.168.1.1 + 1);               # => 192.168.1.2
:put (192.168.1.100 & 255.255.255.0); # => 192.168.1.0 (netmask apply)

# ═══════════════════════════════════════════════════════════════════════════════
#                    FLOW CONTROL ANTI-PATTERNS (from 90+ test verification)
# ═══════════════════════════════════════════════════════════════════════════════

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 25. :break AND :continue EXIST ON 7.22+                                     │
# └─────────────────────────────────────────────────────────────────────────────┘
# Earlier reference releases listed these as non-existent. Per the 7.22
# CHANGELOG: "console - added :continue and :break commands for various loops".
# Verified live on 7.22.2 / 7.23rc2: :break exits :for / :foreach / :while
# early; :continue skips to the next iteration. Both affect only the innermost
# loop. See flow.rsc §6. On 7.21 and earlier the flag-variable workaround
# below is still required.

# ✓ CORRECT (7.22+) - native flow control:
:for i from=1 to=10 do={
  :if ($i = 5) do={ :break; };          # exits at i=5; prints 1..4
  :put $i;
};

# ✓ STILL REQUIRED on 7.21 and earlier - flag-variable workaround:
# :local exitLoop false;
# :for i from=1 to=10 do={
#   :if (!$exitLoop) do={
#     :if ($i = 5) do={ :set exitLoop true; };
#   };
# };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 26. :elseif / elif / else if DOES NOT EXIST                                 │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :if ($x = 1) do={} :elseif ($x = 2) do={};

# ✓ CORRECT - Nest :if inside else:
:if ($x = 1) do={} else={ :if ($x = 2) do={}; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 27. :return WITHOUT VALUE IS ERROR                                          │
# └─────────────────────────────────────────────────────────────────────────────┘
# Empirically verified across all script contexts on 7.23rc2 — see #75 for the
# 7.17 changelog wording that suggested otherwise (proven still false).
# ✗ WRONG:
# :global myFn do={ :return; };  # ERROR: missing value(s) of argument(s)

# ✓ CORRECT:
:global myFn do={ :return ""; };        # Empty string
# VERIFIED REF-AUDIT-RETURN-NOVAL-7.23 2026-04-30 7.23rc2

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 28. STRING IN :if CONDITION IS ERROR                                        │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :if ("text") do={ }  # ERROR: "conditional is not boolean"

# ✓ CORRECT:
:if ([:len "text"] > 0) do={ };         # Check string length

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 29. SHORT-CIRCUIT EVALUATION DOES NOT WORK                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ ASSUMES short-circuit (WRONG):
:if (true || [$expensiveFn]) do={ };    # expensiveFn IS CALLED!

# ✓ CORRECT - Use nested :if:
:if (true) do={} else={ :if ([$expensiveFn]) do={}; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 30. :for with from>to AUTO-ITERATES DESCENDING (NOT WRAP)                   │
# └─────────────────────────────────────────────────────────────────────────────┘
# Prior framing claimed "from>to wraps to max" — FALSIFIED on 7.23rc2.
# REF-AUDIT-FOR-WRAP-DIRECTION 2026-04-30 7.23rc2: from=10 to=5 runs 6 times
# in descending order (10,9,8,7,6,5). Same as step=-1 form — engine infers
# direction from from/to ordering. No infinite loop, no off-by-one.
# ✗ WRONG assumption that this runs 0 times OR wraps to max:
# :for i from=10 to=5 do={}  # Actually runs 6 times in DESCENDING order

# ✓ CORRECT — both forms are equivalent on 7.23rc2:
:for i from=10 to=5 do={ };             # 10,9,8,7,6,5 (auto-descending)
:for i from=10 to=5 step=-1 do={ };     # same — step=-1 is redundant

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 31. SYNTAX ERRORS CANNOT BE CAUGHT                                          │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Parse errors are not runtime errors:
# :onerror e in={ :nonexistent-cmd } do={}  # Script FAILS at parse time!

# ✓ CORRECT - Only runtime errors are catchable

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 32. :quit IS NOT CATCHABLE                                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :onerror e in={ :quit } do={ :put "caught"; }  # Script terminates!

# ✓ CORRECT - Use :error instead for catchable termination:
:onerror e in={ :error "my-exit"; } do={ :put "caught"; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 33. LOOP ITERATOR SCOPE = NOTHING AFTER LOOP                                │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming iterator is available after loop:
:for i from=1 to=5 do={ };
# :put $i;  # $i is "nothing" here!

# ✓ CORRECT - Use separate variable:
:local last 0;
:for i from=1 to=5 do={ :set last $i; };
:put $last;  # => 5

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 34. switch/case AND goto DO NOT EXIST                                       │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - These do not exist:
# switch ($x) { case 1: ... }
# :goto label;

# ✓ CORRECT - Use nested :if or state machine pattern:
:local state "start";
:while ($state != "done") do={
  :if ($state = "start") do={ :set state "step1"; };
  :if ($state = "step1") do={ :set state "done"; };
};

# ═══════════════════════════════════════════════════════════════════════════════
#                    ERROR HANDLING ANTI-PATTERNS (from 400+ test verification)
# ═══════════════════════════════════════════════════════════════════════════════

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 35. :execute ERRORS ARE ISOLATED - NOT CAUGHT BY PARENT!                    │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming parent catches :execute errors:
:local caught false;
:onerror e in={
  [:execute ":error \"test\"" as-string];
} do={
  :set caught true;
};
# caught = false! Execute is isolated!

# ✓ CORRECT - Handle errors inside the executed script

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 36. ARRAY OUT-OF-BOUNDS RETURNS NIL, NOT ERROR!                             │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Expecting error on array access:
:local arr {1;2;3};
:onerror e in={ :local x ($arr->99); } do={ :put "caught"; };
# Handler NOT called - returns nil instead!

# ✓ CORRECT - Check bounds BEFORE accessing:
:if ($idx < [:len $arr]) do={ :local x ($arr->$idx); };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 37. DICT KEY MISS RETURNS "nothing", NOT ERROR!                             │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Expecting error on missing key:
:local dict {"a"=1};
:onerror e in={ :local x ($dict->"nonexistent"); } do={ :put "caught"; };
# Handler NOT called - returns nothing!

# ✓ CORRECT - Check if key exists:
:if ([:typeof ($dict->"key")] != "nothing") do={ :put ($dict->"key"); };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 38. EMPTY FIND IS NOT AN ERROR!                                             │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Expecting error when find is empty:
:onerror e in={
  /interface set [find name="nonexistent"] disabled=yes;
} do={
  :put "caught";
};
# Handler NOT called - set on empty list does nothing!

# ✓ CORRECT - Check find result first:
:local found [/interface find name="ether1"];
:if ([:len $found] > 0) do={ /interface set $found disabled=yes; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 39. :do on-error HAS NO ERROR VARIABLE                                      │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming $e is available:
# :do { :error "x"; } on-error={ :put $e; };  # $e undefined!

# ✓ CORRECT - Use :onerror if you need error message:
:onerror e in={ :error "x"; } do={ :put $e; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 40. NIL OPERATIONS DON'T THROW ERRORS                                       │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Expecting error on nil:
:local nilVar;
:onerror e in={ :local x ($nilVar + 1); } do={ :put "caught"; };
# May not be caught as expected!

# ✓ CORRECT - Check for nil first:
:if ([:typeof $var] != "nothing" && [:typeof $var] != "nil") do={
  :local x ($var + 1);
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 41. UNDERSCORE IS NOT A VALID VARIABLE NAME                                 │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Common pattern from other languages:
# :onerror _ in={ :error "x"; } do={};  # Syntax error!

# ✓ CORRECT - Use named variable:
:onerror e in={ :error "x"; } do={};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 42. :onerror RETURNS BOOL - USE IT!                                         │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✓ USEFUL PATTERN - Use return value for conditionals:
:local hadError [:onerror e in={ :resolve "invalid.xyz"; } do={}];
:if ($hadError) do={
  :put "DNS failed";
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 43. :retry SUCCESS STOPS RETRYING                                           │
# └─────────────────────────────────────────────────────────────────────────────┘
# :retry stops when command succeeds (no error)
:onerror e in={
  :retry command={
    :if ($attempt < 3) do={ :error "retry"; };
    # Success! No more retries
  } delay=0 max=5;
} do={};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 44. ERROR MESSAGE ALWAYS INCLUDES LINE INFO                                 │
# └─────────────────────────────────────────────────────────────────────────────┘
# Error message format: "my-message (:error; line 18)"
# Must parse string to extract original message

# ═══════════════════════════════════════════════════════════════════════════════
#                    ASYNC ANTI-PATTERNS (from 400+ test verification)
# ═══════════════════════════════════════════════════════════════════════════════

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 45. /tool fetch IS BLOCKING! (NOT ASYNC!)                                   │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - LLM assumes fetch is async:
# /tool fetch url="http://example.com/file";  # BLOCKS SCRIPT!

# ✓ CORRECT - Use :execute wrapper for async:
:local j [:execute "/tool fetch url=\"http://example.com/file\" keep-result=no"];
# Returns immediately, fetch runs in background

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 46. :execute RETURNS id TYPE, as-string RETURNS str                         │
# └─────────────────────────────────────────────────────────────────────────────┘
:local jobId [:execute ":put test"];
:put [:typeof $jobId];                  # => id (async)

:local output [:execute ":put test" as-string];
:put [:typeof $output];                 # => str (sync, BLOCKING!)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 47. :execute ERRORS ARE ISOLATED — see #35                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
# Duplicate of #35. Kept as a numbering placeholder so monotonic numbering is
# preserved; full content lives at #35. The rule applies identically to bare
# :execute and :execute ... as-string forms: the child runs as a detached job,
# its errors stay inside the child, and the parent's :onerror does not fire.
# Capture status via :global or /file from inside the child if needed.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 48. :delay DOES NOT SYNC WITH ASYNC JOBS!                                   │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming delay waits for job:
:local j [:execute "long-running-task"];
:delay 5s;  # Does NOT wait for job completion!

# ✓ CORRECT - Poll for job completion:
:while ([:len [/system script job find where .id=$j]] > 0) do={
  :delay 100ms;
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 49. :parse HAS NO CLOSURES!                                                 │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming closure captures outer vars:
:local outerVar "test";
:global fn [:parse ":put \$outerVar"];  # outerVar NOT captured!

# ✓ CORRECT - Pass as parameters:
:global fn [:parse ":put \$1"];
[$fn "value"];

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 50. :parse RETURNS code TYPE — do={...} RETURNS array — see #19             │
# └─────────────────────────────────────────────────────────────────────────────┘
# Construction path determines the type. Both are invocable the same way.
:global myFn [:parse ":put \"hello\""];
:put [:typeof $myFn];                   # => code  (because [:parse ...])
:global myFn2 do={ :put "hello" };
:put [:typeof $myFn2];                  # => array (because do={...})
[$myFn]; [$myFn2];                      # both invoke the same way
# VERIFIED REF-AUDIT-PARSE-TYPEOF 2026-04-30 7.23rc2

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 51. :timestamp RETURNS time TYPE (NOT num!)                                 │
# └─────────────────────────────────────────────────────────────────────────────┘
:local ts [:timestamp];
:put [:typeof $ts];                     # => time (not num!)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 52. NETWATCH RUNS AS sys USER - LIMITED PERMISSIONS!                        │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming full permissions in netwatch:
# /tool netwatch on-down="/tool fetch ..."  # FAILS in v7.13+!

# sys user has: read, write, test, reboot
# sys user LACKS: ftp (required for fetch!)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 53. GLOBALS PERSIST UNTIL REBOOT                                            │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming globals auto-clear:
:global myVar "value";  # Persists forever!

# ✓ CORRECT - Manually unset:
:set myVar;  # Clears variable

# View all globals:
/system script environment print

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 54. ORPHAN JOBS (NO CLEANUP) - RESOURCE LEAK!                               │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Not capturing job ID:
[:execute ":delay 10s"];  # Job ID lost! No way to stop!

# ✓ CORRECT - Always capture and cleanup:
:local j [:execute ":delay 10s"];
:do {/system script job remove $j} on-error={};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 55. /system clock get date RETURNS str TYPE                                 │
# └─────────────────────────────────────────────────────────────────────────────┘
:local d [/system clock get date];
:put [:typeof $d];                      # => str (not time!)

:local t [/system clock get time];
:put [:typeof $t];                      # => time

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 56. v7.10+ DATE FORMAT CHANGED FROM MMM/DD/YYYY TO YYYY-MM-DD               │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming old format:
# :local month [:pick [/system clock get date] 0 3];  # BREAKS in v7.10+!

# ✓ CORRECT - Detect format first:
:local d [/system clock get date];
:if ([:pick $d 4 5] = "-") do={
  # v7.10+ format: YYYY-MM-DD
  :local year [:pick $d 0 4];
  :local month [:pick $d 5 7];
} else={
  # Old format: MMM/DD/YYYY
  :local month [:pick $d 0 3];
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 57. :tonsec RETURNS NANOSECONDS, NOT SECONDS!                               │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming seconds:
# :local sec [:tonsec 1h];  # Returns 3600000000000, NOT 3600!

# ✓ CORRECT - Divide by 1,000,000,000:
:local ns [:tonsec 1h];
:local sec ($ns / 1000000000);  # => 3600

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 58. :timestamp IS NOT UNIX EPOCH SECONDS                                    │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming epoch seconds:
# :local epochSec [:timestamp];  # Returns "2920w5d07:03:45.ns", NOT number!

# ✓ CORRECT - Convert via :tonsec:
:local epochSec ([:tonsec [:timestamp]] / 1000000000);

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 59. TIME TYPE EXTENDS BEYOND 24H (DOES NOT WRAP!)                           │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming 24h wrap:
# 23:00 + 3:00 = 02:00  # WRONG! Actually returns 1d02:00:00

# ✓ ACTUAL BEHAVIOR:
:put (23:00:00 + 3:00:00);  # => 1d02:00:00 (extends with day prefix!)
:put (12h + 36h);            # => 2d00:00:00

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 60. CERTIFICATE DATES USE ISO FORMAT (YYYY-MM-DD) IN v7.10+                 │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming cert dates use old legacy format (MMM/DD/YYYY):
# Cert invalid-after: "dec/25/2025" -> actually "2025-12-25"!

# expires-after = DURATION REMAINING (time type), invalid-after = string (ISO)!
:local expiresAfter [/certificate get $cert expires-after];  # => 4w1d...
:local invalidAfter [/certificate get $cert invalid-after];  # => "2025-..."

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 61. scheduler start-time IS STRING (NOT time TYPE!)                         │
# └─────────────────────────────────────────────────────────────────────────────┘
:local startTime [/system scheduler get myTask start-time];
:put [:typeof $startTime];  # => str (NOT time!)

# ┌─────────────────────────────────────────────────────────────────────────────┘
# │ 62. script last-started IS STRING (NOT time TYPE!)                          │
# └─────────────────────────────────────────────────────────────────────────────┘
:local lastStarted [/system script get myScript last-started];
:put [:typeof $lastStarted];  # => str (format: "YYYY-MM-DD HH:MM:SS")

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 63. gmt-offset IS num (NOT time TYPE!)                                      │
# └─────────────────────────────────────────────────────────────────────────────┘
:local offset [/system clock get gmt-offset];
:put [:typeof $offset];  # => num (seconds offset from UTC)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 64. ADDRESS-LIST TIMEOUT ENTRIES ARE LOST ON REBOOT!                        │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming timeout entries persist:
/ip firewall address-list add list=blocklist address=1.2.3.4 timeout=1d;
# This is DYNAMIC (RAM only), LOST on reboot!

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 65. NTP DOES NOT SYNC IMMEDIATELY - CLOCK STARTS AT 1970!                   │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Using date immediately after boot:
# Scheduler scripts may fire with wrong dates before NTP syncs!

# ✓ CORRECT - Wait for NTP sync:
:local timeout 0;
:while (([/system/ntp/client/get status] != "synchronized") && $timeout < 30) do={
  :delay 1s; :set timeout ($timeout + 1);
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 66. /log print as-value DOES NOT SUPPORT count                              │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Using count with as-value:
# :local logs [/log print as-value count=5];  # FAILS (Syntax Error)

# ✓ CORRECT - Use where to filter, or filtering loop:
:local logs [/log print as-value where topics~"system"];

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 67. LOG TIME IS str TYPE (ISO FORMAT)                                       │
# └─────────────────────────────────────────────────────────────────────────────┘
:local t [/log get $id time];
:put [:typeof $t];  # => str (e.g. "2025-12-23 07:13:04")
# Note: It is NOT time type!

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 68. /ip firewall ... find where <str-valued predicate> REQUIRES QUOTES      │
# └─────────────────────────────────────────────────────────────────────────────┘
# In `find where` clauses, string/enum-valued predicate literals MUST be quoted
# string-literals. Unquoted bare words parse as variable references and evaluate
# to "nothing", producing a silent no-match (empty result). This is asymmetric
# with the corresponding /add command which accepts unquoted values as a
# convenience — so the same value works in `add` but fails in `find`.
#
# Verified on RouterOS 7.23rc2 (2026-04-24).

# ✗ WRONG - unquoted protocol, port, action → silent zero-match
# :local found [/ip firewall filter find where chain=input protocol=tcp dst-port=80 action=accept]
# # => "" (empty), even when matching rules exist!

# ✓ CORRECT - quote every string/enum literal in the `where` predicate
:local found [/ip firewall filter find where chain=input protocol="tcp" dst-port="80" action="accept"]
# => matches existing rules as expected.

# Note: `chain=input` (without quotes) DOES work because `input` is a chain-name
# symbol recognised by the parser. But `protocol=tcp`, `action=accept`,
# `dst-port=80`, `src-port=443` etc. all need explicit quoting.
#
# CAVEAT — boolean predicates follow the OPPOSITE rule. Fields whose schema
# type is `bool` (`dynamic`, `disabled`, `passthrough`, `log`, `invalid`, etc.)
# accept ONLY bare `yes`/`no` in `find where`; quoting them silently no-matches.
# Verified live 7.23rc2:
#   /ip firewall address-list find where list=blocklist dynamic="yes"   => 0
#   /ip firewall address-list find where list=blocklist dynamic=yes     => N
# So "when in doubt, quote" is true ONLY for string/enum predicates. For
# boolean predicates the safe form is the bare word.
#
# Symptoms when this bug hits:
#   - Idempotent "install if missing" loops create duplicate rules on every run.
#   - Scripts that update/disable a rule "by comment" silently do nothing.
#   - Unit-test equality of a single found-rule collapses to the no-match case.
#   - A diff-sync runtime that filters by `dynamic="yes"` deletes nothing on
#     re-runs and re-adds every entry, exploding adds/errors counts.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 69. SEQUENTIAL [$fnA ...]; [$fnB ...] INSIDE A FUNCTION CAN RE-INVOKE fnA   │
# └─────────────────────────────────────────────────────────────────────────────┘
# Inside a `:global … do={ … }` function body, calling two global function
# handles sequentially — [$fnA args]; [$fnB args] — can cause fnA to be
# invoked a SECOND time alongside fnB. The spurious re-invocation fires real
# side effects (logs, system changes) with the ORIGINAL arguments.
#
# Verified on RouterOS 7.23rc2 (2026-04-24). Root cause not confirmed at the
# interpreter source level; hypothesis is an implicit "last-called-handle"
# that gets re-invoked on the next `[$x …]` expression in the same scope.
#
# Does NOT reproduce:
#   - At script top level (outside any function).
#   - When the second call uses :if/:onerror gating (the `:if` body appears
#     to break the chain trigger).
#   - When one of the calls is a builtin (:log info …, :put …) rather than
#     a `[$globalFn …]` invocation.

# ✗ WRONG - inside a function body; fnA fires twice, the second time right
#           after fnB logs its own message.
# :global fnA do={ :log info "A"; :return "" }
# :global fnB do={ :log info "B"; :return "" }
# :global caller do={
#   :global fnA; :global fnB
#   [$fnA "first"]        # logs A (expected)
#   [$fnB "second"]       # logs B (expected) AND fires A again (bug)
#   :return ""
# }

# ✓ WORKAROUND 1 - gate the second call with :if on the first's boolean result
:global fnA do={ :log info ("A:" . $1); :return true }
:global fnB do={ :log info ("B:" . $1); :return true }
:global callerOk do={
  :global fnA; :global fnB
  :if ([$fnA "first"]) do={ [$fnB "second"] }
  :return ""
}

# ✓ WORKAROUND 2 - replace one of the calls with a builtin
:global callerInline do={
  :global fnA
  [$fnA "first"]
  :log info "B via builtin"    # no chain — no spurious re-invocation
  :return ""
}

# ✓ WORKAROUND 3 - assignment form between the two calls
:global callerAssign do={
  :global fnA; :global fnB
  :local r1 [$fnA "first"]
  :if ($r1) do={ [$fnB "second"] }
  :return ""
}

# Symptoms when this bug hits:
#   - Log entries duplicated or appearing at unexpected points.
#   - Side-effectful state (firewall rules toggled, services enabled/disabled)
#     reverting or double-applying between expected lines of code.
#   - Instrumented tracing reveals two invocations of fnA per single lexical
#     call site — the second invocation happens AFTER fnB has started.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 70. :exit IS NOT :break — TERMINATES THE WHOLE SCRIPT (7.22+, silent)       │
# └─────────────────────────────────────────────────────────────────────────────┘
# `:exit` was added in 7.22. It looks like a loop-control primitive, but it
# terminates the ENTIRE script — same blast radius as `:quit`. The only
# differences from `:quit` are: it's silent (no "interrupted" output) and
# it accepts NO argument (`:exit "msg"` / `:exit 1` are parse errors).
# `:onerror` cannot catch `:exit` (it is not an error condition).

# ✗ WRONG — using :exit to break out of a loop:
# :foreach i in={1;2;3;4} do={
#   :if ($i = 2) do={ :exit }     # ABORTS the whole script, not the loop!
#   :put $i
# }
# :put "after-loop";              # NEVER reached

# ✓ CORRECT — :break for loop, :exit only when you mean "stop the script":
:foreach i in={1;2;3;4} do={
  :if ($i = 2) do={ :break }      # exits innermost loop only (7.22+)
  :put $i;                        # prints 1
}
:put "after-loop";                # reached

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 71. FN ARG SILENTLY CAPTURED FROM :global ON 7.22+ WHEN COLLISION EXISTS    │
# └─────────────────────────────────────────────────────────────────────────────┘
# 7.22 added: when a function references `$x` and `x` is neither an arg nor a
# `:local`, the lookup falls back to `:global x`. Pre-7.22 this returned empty.
# RISK: if your function expects an arg whose name happens to match an
# existing :global, forgetting to pass the arg silently captures the global.

# ✗ WRONG — name collision with a pre-existing :global:
# :global state "production"        # set elsewhere
# :global doWork do={ :put $state }  # author meant arg "state"
# [$doWork]                          # 7.22+: prints "production" (stale capture!)
#                                    # <7.22: prints empty (caller noticed bug)

# ✓ CORRECT — pass args explicitly, OR rename to avoid global namespace:
:global state "production"
:global doWork do={
  :if ([:typeof $arg] = "nothing") do={ :error "state arg required" }
  :put $arg
}
[$doWork arg="staging"];           # explicit; never depends on fallback

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 72. WRITE TO :global FROM INSIDE FN STILL NEEDS :global X; RE-DECL          │
# └─────────────────────────────────────────────────────────────────────────────┘
# 7.22 relaxed READ access (auto-fallback to :global). It did NOT relax WRITE.
# `:set X` inside a function where `X` was not declared as :local or :global
# is a PARSE-time error on every version, including 7.22+.

# ✗ WRONG — implicit :set on a global:
# :global counter 0
# :global bump do={ :set counter ($counter + 1) }    # parse error: syntax error
# [$bump]

# ✓ CORRECT — explicit :global X; before :set:
:global counter 0
:global bump do={
  :global counter;                 # required for :set, even on 7.22+
  :set counter ($counter + 1);
}
[$bump];
:put $counter;                     # => 1

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 73. id < "*FF" ERRORS ON 7.22+ — ID ORDERING DOES NOT COERCE TO STRING      │
# └─────────────────────────────────────────────────────────────────────────────┘
# 7.22+ added <, >, <=, >= for `id` values. Equality (`=`) coerces str<->id;
# ordering does NOT — comparing an `id` against a `str` raises a runtime error.
# Strings still don't support `<`/`>` either (existing rule).

# ✗ WRONG — relying on coercion for ordering:
# :local first ([/interface find]->0)
# :put ($first < "*FFFFFFFF")        # ERROR: cannot compare if id is less than string

# ✓ CORRECT — both sides must be id (or both num/ip):
:local ids [/interface find]
:local a ($ids->0); :local b ($ids->1);
:put ($a < $b);                    # 7.22+: bool — both operands are id
# To compare against a literal id, write the *XX form WITHOUT quotes:
# (assumes *1 exists)
# :put ($a < *FFFFFFFF);             # OK — both id-typed

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 74. :tobool ON time TYPE RETURNS nil (THE ONLY EXCEPTION ON 7.22+)          │
# └─────────────────────────────────────────────────────────────────────────────┘
# 7.22 made :tobool universal — except for `time`. Every other type coerces
# (str/num/bool/ip/ip6/id/array/nil all return bool). Only `time` returns nil.
# Code that uses :tobool for a "is this duration set?" check will silently
# fail because nil is falsy when concatenated but is NOT the bool false.

# ✗ WRONG — checking a time value with :tobool:
# :local duration 5s
# :if ([:tobool $duration]) do={ ... }   # 7.22+: nil — :if rejects non-bool!
#                                        # raises "conditional is not boolean"

# ✓ CORRECT — coerce time to nanoseconds first:
:local duration 5s
:if ([:tonsec $duration] > 0) do={ :put "duration set"; }
# Or compare against zero directly:
:if ($duration > 0s) do={ :put "duration set"; }

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 75. :return WITHOUT VALUE STILL ERRORS ON 7.23rc2 (7.17 FIX INTERNAL)       │
# └─────────────────────────────────────────────────────────────────────────────┘

# The 7.17 changelog "console - execute :return command without error" suggested
# bare :return; would become valid. Empirically (verified 2026-04-30 on 7.23rc2,
# REF-AUDIT-RETURN-NOVAL-7.23): bare :return; in EVERY context tested (top-
# level, fn body, :do, :if, :foreach, :onerror handler) STILL raises:
#     Script Error: missing value(s) of argument(s) value (:return; line N)
# The 7.17 fix appears to be a narrower internal compiler refactor; user-facing
# behavior is unchanged. The error IS now catchable via :onerror — see #27 for
# the basic guidance. This entry adds the version-context detail.
# ✗ WRONG:
# :global cleanup do={ :put "x"; :return; }      # missing value error on call
# :do { :return; } on-error={ :put "caught" }    # caught — error IS catchable
# Top-level: :return "x" THROWS x as the error message (not a return-from-script):
# :return "early";                               # Script Error: early (:import; ...)
# ✓ CORRECT — always provide an explicit value (use empty string for "no value"):
:global cleanup do={ :put "doing cleanup"; :return ""; }
:global cleanup2 do={ :return value=""; }
# When you mean "stop the whole script silently", use :exit (7.22+), not :return.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 76. :onerror REQUIRES in= AND ERROR-VAR; do= IS OPTIONAL ON 7.15+           │
# └─────────────────────────────────────────────────────────────────────────────┘

# 7.15 fixed :onerror behavior when do= is absent — formalising do= as optional.
# Authors sometimes flip the requirements (omit in= or error-var). Empirically on
# 7.23rc2: in= and the error variable name are MANDATORY on every version; do=
# is optional on 7.15+ and behaves as `do={}` (suppresses the error, return value
# is still bool).
# ✗ WRONG:
# :onerror in={ :error "x" } do={ };       # missing value of argument error
# :onerror e do={ :put "h" };              # missing value(s) of argument(s) in
# :onerror;                                # missing value of argument error
# ✓ CORRECT — minimum valid form on 7.15+:
:onerror e in={ :error "may-fail" };                   # do= can be omitted
:local hadErr [:onerror e in={ :error "x" }];          # => true  (still bool!)
:local noErr  [:onerror e in={ :put "ok" }];           # => false
:onerror e in={ :error "x" } do={ :put $e; };          # full form when handling needed

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 77. :tolower / :toupper / transform=uppercase DO NOT EXIST                  │
# └─────────────────────────────────────────────────────────────────────────────┘

# A common LLM hallucination: :tolower / :toupper standalone commands, OR
# :convert transform=uppercase / lowercase. NONE of these forms exist on any
# RouterOS 7.x verified through 7.23rc2. The actual ENUM values for case
# transform are uc / lc / ucfirst / lcfirst / none (added 7.16+).
# ✗ WRONG:
# :put [:tolower "Hello"];                       # bad command name tolower
# :put [:toupper "Hello"];                       # bad command name toupper
# :put [:convert "Hello" transform=uppercase];   # input does not match any value
# :put [:convert "Hello" transform=lowercase];   # input does not match any value
# :put [:convert "Hello" transform=upper];       # parse error
# ✓ CORRECT — :convert transform= with the actual enum tokens (7.16+):
:put [:convert "Hello World" transform=uc];     # => HELLO WORLD
:put [:convert "Hello World" transform=lc];     # => hello world
:put [:convert "hello"       transform=ucfirst]; # => Hello   (first char only)
:put [:convert "HELLO"       transform=lcfirst]; # => hELLO
# ASCII-only — UTF-8 multibyte (Cyrillic, accented Latin) passes through:
:put [:convert "ПРИВЕТ" transform=lc];           # => ПРИВЕТ  (NOT lowercased)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 78. :convert to=lf / from=lf / to=crlf DO NOT EXIST — USE transform=lf/crlf │
# └─────────────────────────────────────────────────────────────────────────────┘

# Line-ending normalization in 7.17+ is exposed as transform=lf / transform=crlf,
# NOT as to= / from= destinations. The 7.17 changelog correctly says "added
# lf/crlf options to :convert transform" — the give-away word is "transform".
# Bare :tolf / :tocrlf standalone commands also exist as aliases (7.14+).
# ✗ WRONG:
# :local s [:convert "a\r\nb" to=lf];          # syntax error
# :local s [:convert "a\nb"  to=crlf];          # syntax error
# :local s [:convert "a\nb"  from=lf];          # syntax error
# ✓ CORRECT — transform=lf / transform=crlf, or the standalone aliases:
:put [:len [:convert "a\r\nb\r\nc" transform=lf]];   # => 5  (\r\n -> \n)
:put [:len [:convert "a\nb\nc"     transform=crlf]];   # => 7  (\n -> \r\n)
:put ([:tolf   "a\r\nb"] = [:convert "a\r\nb" transform=lf]);     # => true
:put ([:tocrlf "a\nb"]   = [:convert "a\nb"   transform=crlf]);   # => true

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 79. BYTE-ARRAY CONCATENATION ITERATES (ONE LINE PER BYTE)                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# [:convert <x> to=byte-array] returns an `array` of nums (each byte 0-255), and
# array operands of the . operator unfold ELEMENT-BY-ELEMENT in :put — so
# ("prefix " . $ba) prints "prefix 97" then "prefix 98" etc., one line per byte.
# ✗ WRONG:
# :local ba [:convert "Hello" to=byte-array];
# :put ("len=" . $ba);                          # 5 lines: len=72, len=101, ...
# ✓ CORRECT — :put $ba directly (no concat) OR [:tostr $ba] for joined string:
:local ba [:convert "Hello" to=byte-array];
:put $ba;                                       # => 72;101;108;108;111  (one line)
:put ("bytes=" . [:tostr $ba]);                 # => bytes=72;101;108;108;111
:put ("len="   . [:len   $ba]);                 # => len=5
:put ("first=" . ($ba->0));                     # => first=72

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 80. :convert to=num RETURNS str + SILENT 8-BYTE CEILING                     │
# └─────────────────────────────────────────────────────────────────────────────┘

# :convert "X" to=num packs bytes into a 64-bit big-endian unsigned integer and
# returns it as a STRING (typeof str), NOT a num. Inputs longer than 8 bytes
# silently produce "" — no error raised. Equally subtle: from=num 0 returns a
# single NUL byte ("\0", len 1), NOT the empty string. (7.17+)
# ✗ WRONG:
# :local n [:convert $userInput to=num];
# :if ($n > 1000) do={ ... };                   # $n is str — string comparison
# :if ($n = 0) do={ ... };                      # only true on empty input
# ✓ CORRECT — bound-check inputs and convert :tonum if you need numeric ops:
:local s "Hi";
:local n [:convert $s to=num];                  # => str "18537"  (= 0x4869)
:put [:typeof $n];                              # => str
:if ([:len $s] > 8) do={ :error "to=num cannot pack > 8 bytes"; }
:put [:tonum $n];                               # => 18537 (now num for arithmetic)
:put [:len [:convert 0 from=num]];              # => 1   (single NUL byte!)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 81. :convert to=url DOES NOT ENCODE %, \t, HIGH-BIT BYTES, OR DEL           │
# └─────────────────────────────────────────────────────────────────────────────┘

# Even on 7.15+ (which "added spaces, CR, LF" coverage), :convert to=url leaves
# several bytes UN-encoded: literal %, tab (0x09), 0x00-0x1F except CR/LF,
# DEL (0x7F), and ALL 0x80-0xFF (UTF-8 multibyte). RouterOS-encoded URLs that
# contain user input may not be RFC 3986 conformant; round-trip via from=url is
# lossy when the original has any of those bytes. from=url silently returns ""
# on bad %-hex (%ZZ, %2, lone %).
# ✗ WRONG:
# :local enc [:convert ("rate=100% " . $cyrillic) to=url];
# /tool fetch url=("https://api?q=" . $enc);    # MAY FAIL: % stays bare; UTF-8 stays bare
# :put ([:convert $enc from=url] = $orig);      # => false (lossy round trip)
# ✓ CORRECT — pre-validate input or use :convert to=hex / to=base64 for raw bytes:
:local safe [:convert "hello world" to=url];   # => hello%20world (ASCII-only)
:put [:convert "Привет" to=hex];               # => d09fd180d0b8d0b2d0b5d182
:put [:convert "Привет" to=base64];            # => 0J/RgNC40LLQtdGC

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 82. :range HAS NO step= PARAMETER (7.17+)                                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# Developers porting from Python's range(start, stop, step) or Lua's for loop
# expect a stride parameter on :range. On 7.23rc2, [:range from=N to=M] accepts
# only those two named arguments (and a 2-positional form). step= / increment=
# / by= are all rejected with "bad parameter step".
# ✗ WRONG:
# :foreach v in=[:range from=1 to=10 step=2] do={ :put $v }
# # => Script Error: bad parameter step
# ✓ CORRECT — emulate stride via modulo filter, OR use :for which does support step=
:foreach v in=[:range from=1 to=10] do={
  :if (($v % 2) = 1) do={ :put $v };           # => 1 3 5 7 9
}
:for i from=1 to=10 step=2 do={ :put $i };     # => 1 3 5 7 9
# Hard cap: :range output > 1,000,000 elements raises "size of the ranged array
# is too large (max 1000000)". Use :for for unbounded iteration.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 83. :rndnum from > to RETURNS GARBAGE INT64 (NO ERROR)                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# When :rndnum is called with from > to it does NOT error and does NOT clamp;
# it returns an arbitrary int64 (often a giant negative from uninitialised
# memory). Reproducible 7.23rc2: [:rndnum from=10 to=1] -> -7956501532190287755.
# ✗ WRONG:
# :local pick [:rndnum from=$max to=$min];     # silent garbage when max > min
# ✓ CORRECT — always order arguments low->high; defend with a swap:
:local lo $min;
:local hi $max;
:if ($lo > $hi) do={ :local tmp $lo; :set lo $hi; :set hi $tmp; }
:local pick [:rndnum from=$lo to=$hi];

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 84. :grep IS NOT A STRING-SEARCH UTILITY — IT EXECUTES SCRIPT=              │
# └─────────────────────────────────────────────────────────────────────────────┘

# The name suggests Unix grep on a string; on RouterOS, :grep RUNS its script=
# argument (RouterOS source) and counts STDOUT LINES that match pattern= (regex).
# Calling [:grep "haystack" "needle"] does NOT search the haystack — it tries to
# execute "haystack" as a script.
# ✗ WRONG:
# :local hits [:grep $logText "ERROR"];        # tries to run $logText as a script
# ✓ CORRECT — substring/regex search of an in-memory string:
:if ([:find $logText "ERROR"] >= 0) do={ :put "found"; }
:if ($logText ~ "ERROR|FAIL")    do={ :put "match"; }
# Genuine :grep usage — run a print and count matching lines:
:local errCount [:grep script="/log print" pattern="error"];

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 85. :lock IS A NO-OP IN NON-INTERACTIVE SCRIPTS                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# 7.16 changelog says ":lock command to lock screen". In non-interactive
# script context (/import, ros-deploy, /system script run), :lock returns
# immediately (~20us) and does NOT block, even with delay=5s. Verified on
# 7.23rc2: [:time {:lock delay=5s}] elapses ~23 microseconds.
# ✗ WRONG:
# :lock delay=30s;                              # writer expected a 30s pause
# :put "after 30s";                             # actually prints immediately
# ✓ CORRECT — use :delay for pauses; :lock is interactive-console only:
:delay 30s;
:put "after 30s";

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 86. :rndstr CHARSET IS FIXED — NO source= / alphabet= ON 7.23rc2            │
# └─────────────────────────────────────────────────────────────────────────────┘

# Developers may try [:rndstr length=20 source="0123456789"] or
# alphabet= / chars= / type= expecting custom-alphabet random strings; all
# such parameters are rejected on 7.23rc2 with "expected end of command".
# Default length is 16; fixed alphabet [A-Za-z0-9].
# ✗ WRONG:
# :local digits [:rndstr length=8 source="0123456789"];
# # => Script Error: expected end of command
# ✓ CORRECT — build a custom-alphabet random string manually:
:local alphabet "0123456789"
:local out ""
:for i from=1 to=8 do={
  :local idx [:rndnum from=0 to=([:len $alphabet] - 1)];
  :set out ($out . [:pick $alphabet $idx ($idx + 1)]);
}
:put $out

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 87. :resolve type= IS ADDRESS-FAMILY SELECTOR, NOT DNS-RECORD-TYPE          │
# └─────────────────────────────────────────────────────────────────────────────┘

# The 7.15 changelog "added type parameter to :resolve" is misleading. The
# accepted value-set is {ipv4, ipv6, any, any6} — address-family selection.
# DNS record-type names (A, AAAA, MX, TXT, NS, CNAME, SOA, SRV, PTR) are ALL
# rejected at runtime ("input does not match any value of type"). Bare
# uppercase identifiers (type=A) are PARSE errors before runtime.
# ✗ WRONG:
# :put [:resolve "google.com" type=A];          # parse error (uppercase ident)
# :put [:resolve "google.com" type="A"];        # runtime error (no match)
# :put [:resolve "google.com" type="MX"];       # runtime error (no match)
# ✓ CORRECT — address-family selection only:
:put [:resolve "google.com" type=ipv4];        # => 142.251.x.x   (ip)
:put [:resolve "google.com" type=ipv6];        # => 2a00:...      (ip6)
:put [:resolve "google.com" type=any];         # IPv4 preferred, fallback v6
:put [:resolve "google.com" type=any6];        # IPv6 preferred, fallback v4
# For MX/TXT/SRV/etc. queries, :resolve is NOT the right tool — use
# /ip dns static find on locally-configured records, or /tool fetch a DoH endpoint.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 88. :totime ISO T-SEPARATOR RETURNS nil — USE SPACE DELIMITER               │
# └─────────────────────────────────────────────────────────────────────────────┘

# 7.18 added "ISO timezone format" support to :totime, but the parser REJECTS
# T-separator forms (the default output of JavaScript toISOString(), Python
# isoformat(), C# DateTimeOffset, etc.) — they return nil silently. Space
# delimiter is REQUIRED. LLMs/integrations emitting ISO timestamps will hit
# silent nil values that propagate into downstream code.
# ✗ WRONG:
# :local t [:totime "2026-04-30T12:00:00Z"];     # => nil silently
# :local t [:totime "2026-04-30T12:00:00.123Z"]; # => nil silently
# :local t [:totime "2026-04-30T12:00:00"];      # => nil silently
# ✓ CORRECT — convert T-separator to space, then check for nil via :typeof:
:global parseIso8601 do={
  :local s $1
  :local p [:find $s "T"]
  :if ([:typeof $p] != "nil") do={
    :set s ([:pick $s 0 $p] . " " . [:pick $s ($p+1) [:len $s]])
  }
  :local t [:totime $s]
  :if ([:typeof $t] = "nil") do={ :error ("bad ISO timestamp: " . $1); }
  :return $t
}
:put [$parseIso8601 "2026-04-30T12:00:00Z"];   # => 2939w12:00:00

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 89. :totime SILENTLY DISCARDS TIMEZONE OFFSET                               │
# └─────────────────────────────────────────────────────────────────────────────┘

# :totime accepts most TZ markers (Z, GMT, UTC, +HHMM, -HHMM, even garbage
# like "+abc" or "PST") but performs NO offset arithmetic — the wall-clock
# value is returned as-is regardless of timezone. Treating a "+02:00" timestamp
# as if it were converted to local/UTC produces silent off-by-N-hours bugs.
# ✗ WRONG:
# :local t [:totime "2026-04-30 14:00:00+0200"]; # => 2939w14:00:00 (NOT 12:00)
# # Caller assumed TZ was applied — silent 2-hour bug.
# :local t [:totime "2026-04-30 12:00:00 garbage"]; # => 2939w12:00:00 (!! "garbage" swallowed)
# ✓ CORRECT — apply offset arithmetic manually; treat TZ marker as documentation only:
:local raw [:totime "2026-04-30 14:00:00"];   # naive parse
:local utc ($raw - 02:00:00);                  # subtract +0200 manually for UTC

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 90. :totime NIL CHECK MUST USE [:typeof], NOT = nil                         │
# └─────────────────────────────────────────────────────────────────────────────┘

# :totime returns nil silently on invalid input. Comparing the result to the
# nil keyword via `=` returns FALSE even when the value is genuinely nil
# (because nil interpolates to empty string in this context). Use
# `[:typeof $x] = "nil"` for nil-safety. Same idiom applies to any function
# whose failure sentinel is nil (:tonum on bad input, :toip on bad input, etc.).
# ✗ WRONG:
# :local t [:totime $userInput];
# :if ($t = nil) do={ :error "bad timestamp"; } # NEVER fires (false even when nil)
# ✓ CORRECT:
:local t [:totime $userInput];
:if ([:typeof $t] = "nil") do={ :error ("bad timestamp: " . $userInput); }

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 91. :resolve vrf= IS NOT A VALID PARAMETER ON 7.23rc2                       │
# └─────────────────────────────────────────────────────────────────────────────┘

# A 7.15-era changelog mentioned VRF support for :resolve, but on 7.23rc2 the
# parameter is rejected with "bad parameter vrf". The accepted parameters are
# domain-name=, type=, and server= only. VRF control happens at the DNS
# service level (/ip dns set vrf=...), not at the :resolve call.
# ✗ WRONG:
# :put [:resolve "google.com" vrf=main];        # => bad parameter vrf
# :put [:resolve "google.com" vrf=mgmt];        # => bad parameter vrf
# ✓ CORRECT — set DNS service VRF once at config time:
# /ip dns set vrf=mgmt
:put [:resolve "google.com" type=ipv4 server=8.8.8.8];

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 92. PASSING do= OR on-error= AS A VARIABLE (REJECTED ON 7.19+)              │
# └─────────────────────────────────────────────────────────────────────────────┘

# Since 7.19 RouterOS strictly validates do= and on-error= arguments and rejects
# any indirect form: do=$var, do=$fn, on-error=$handler. Even a properly-built
# `:local fn do={...}` cannot be passed via `do=$fn` — the engine demands an
# inline {...} literal at the parse site. The error is "invalid value for
# argument do (...)" and is NOT catchable (parser-level, preempts execution).
# Pre-7.19 silently accepted these forms; 7.19+ aborts the whole script.
# ✗ WRONG:
# :local handler do={ :put ("err " . $i); }
# :foreach i in=({1;2}) do={ :error "x" } on-error=$handler;
# # => Script Error: invalid value for argument on-error
# :local body do={ :put $i; }
# :foreach i in=({1;2}) do=$body;             # => same error
# ✓ CORRECT — keep blocks inline; if reusable, call a global function from inside:
:global myHandler do={ :put ("handle " . $1); };
:foreach i in=({1;2;3}) do={
  :if ($i = 2) do={ :error "x"; };
} on-error={ [$myHandler $i]; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 93. ASSUMING LOOP on-error= EXPOSES THE ERROR MESSAGE                       │
# └─────────────────────────────────────────────────────────────────────────────┘

# The 7.19 :foreach/:for on-error={...} handler runs in the LOOP scope (loop
# iterator and outer locals visible) but the raised error message is NOT bound
# to any variable inside the handler. None of $1, $err, $e, $errVar, $error,
# $errstr, $message, $reason, $exception resolve. The handler is fire-and-forget.
# Named-binding syntaxes (on-error errVar={...}, error-var=name) all parse-error.
# VERIFIED REF-AUDIT-FOREACH-ON-ERROR-BIND 2026-04-30 7.23rc2.
# ✗ WRONG:
# :foreach i in=({1;2}) do={ :error "boom" } on-error={ :put $err; };
# # $err is "nothing"
# :foreach i in=({1;2}) do={ :error "boom" } error-var=msg on-error={ :put $msg; };
# # => Script Error: bad parameter error-var
# ✓ CORRECT — capture via outer :onerror + re-raise from handler, OR use the
# loop iterator (which IS bound to the failing iteration):
:onerror outer in={
  :foreach i in=({1;2;3}) do={
    :if ($i = 2) do={ :error "primary"; };
  } on-error={ :error ("rethrow at " . [:tostr $i]); };
} do={ :log error ("loop failed: " . $outer); };
# Or just log the failing iterator (no message available):
:foreach i in=({1;2;3}) do={ :if ($i = 2) do={ :error "x"; } } on-error={
  :log warning ("iter " . $i . " failed");
}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 94. USING LOOP on-error= TO TERMINATE THE LOOP ON FIRST ERROR               │
# └─────────────────────────────────────────────────────────────────────────────┘

# The DEFAULT semantic of :foreach/:for on-error={...} is CONTINUE: after the
# handler runs, the loop steps to the next iteration. This is the OPPOSITE of
# :onerror in={...} do={...} (catch-once-and-exit) and the OPPOSITE of
# :do{} on-error={} (try/catch). LLMs that read "on-error" as "catch and stop"
# will silently let a loop iterate over hundreds of failing items.
# ✗ WRONG:
# :foreach i in=({1;2;3;4;5}) do={
#   :if ($i = 2) do={ :error "boom"; };           # writer expected loop to STOP
#   /file/some-side-effect $i;
# } on-error={ :log error "stop"; };
# # Reality: i=2 errors -> handler logs -> i=3,4,5 ALL still execute
# ✓ CORRECT — :break inside the handler stops on first error:
:foreach i in=({1;2;3;4;5}) do={
  :if ($i = 2) do={ :error "boom"; };
} on-error={
  :log error ("stop at " . $i);
  :break;                                         # 7.22+; exits the foreach
};
# Or :return inside a function body to terminate the function.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 95. EXPECTING OUTER :onerror TO CATCH ERRORS FROM A LOOP WITH on-error={}   │
# └─────────────────────────────────────────────────────────────────────────────┘

# When a :foreach/:for has its own on-error={...}, the error is fully consumed
# there. An enclosing :onerror outer in={...} do={...} does NOT fire unless the
# handler explicitly re-raises via :error. Library users coming from try/catch
# languages assume the outer always wins; in 7.19+ it does not.
# ✗ WRONG:
# :onerror caught in={
#   :foreach i in=({1;2;3}) do={ :if ($i = 2) do={ :error "boom"; } }
#   on-error={ :put "inner-handler"; };
# } do={ :put ("OUTER caught: " . $caught); };
# # Output: "inner-handler" — outer's do={} body NEVER runs.
# ✓ CORRECT — drop inner on-error= (let outer catch), OR re-raise from handler:
:onerror caught in={
  :foreach i in=({1;2;3}) do={
    :if ($i = 2) do={ :error "boom"; };
  } on-error={
    :log warning ("iter " . $i . " failed, re-raising");
    :error ("loop-failed-at-" . [:tostr $i]);
  };
} do={ :put ("OUTER caught: " . $caught); };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 96. USING dsv.remap ON :deserialize OR ON FLAT (NON-DICT) ARRAYS            │
# └─────────────────────────────────────────────────────────────────────────────┘

# The 7.18 dsv.remap option is RECOGNIZED ONLY by :serialize, and ONLY when
# the value is an array of dictionaries (e.g. [/interface print as-value]).
# Passing it to :deserialize is a syntax error (parse-time, NOT catchable).
# Passing it to :serialize on a flat scalar array errors "input not an array";
# on an array of arrays it silently emits "". The CORRECT inverse for
# :deserialize is dsv.array (header -> array-of-dicts) or dsv.plain (no header).
# ✗ WRONG:
# :deserialize from=dsv value=$csv delimiter="," options=dsv.remap;
# # => Script Error: syntax error (parse-time, not catchable)
# :serialize to=dsv value=({1;2;3}) delimiter="," options=dsv.remap;
# # => Script Error: input not an array
# ✓ CORRECT — forward + reverse with the proper option pair:
:local rows [/interface print as-value];
:local csv  [:serialize to=dsv value=$rows delimiter="," options=dsv.remap];
:local back [:deserialize from=dsv value=$csv delimiter="," options=dsv.array];
:put (($back->0)->"name");                       # access first row's "name" col
:local matrix [:deserialize from=dsv value="1,2,3\n4,5,6" delimiter="," options=dsv.plain];
:put (($matrix->1)->2);                          # row 1, col 2 -> 6

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 97. DRY-RUN IMPORT WITHOUT verbose=yes/progress (7.16+)                     │
# └─────────────────────────────────────────────────────────────────────────────┘

# /import dry-run is verbose-only — using it without verbose=yes/progress raises
# a catchable error. Library users often expect dry-run to be a standalone flag
# that suppresses output too — it isn't.
# ✗ WRONG:
# /import file-name="config.rsc" dry-run;
# # => Error: "dry-run parameter cannot be used in non-verbose mode"
# ✓ CORRECT — pair dry-run with one of the verbose modes:
/import file-name="config.rsc" verbose=yes dry-run;       # full announcement
/import file-name="config.rsc" verbose=progress dry-run;  # output-only (quieter)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 98. dry-run=yes INSTEAD OF BARE dry-run FLAG (7.16+)                        │
# └─────────────────────────────────────────────────────────────────────────────┘

# /import dry-run is a bare flag, NOT a key=value parameter. Writing
# dry-run=yes raises a parse error ("expected end of command") that the LLM
# might misdiagnose as a script syntax problem. Stacking the flag
# (dry-run dry-run) raises "bad parameter dry-run".
# ✗ WRONG:
# /import file-name="config.rsc" verbose=yes dry-run=yes;
# # => Parse error: expected end of command at "=yes"
# ✓ CORRECT — bare flag, no value:
/import file-name="config.rsc" verbose=yes dry-run;

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 99. TRUSTING DRY-RUN TO CATCH RUNTIME ERRORS                                │
# └─────────────────────────────────────────────────────────────────────────────┘

# dry-run only validates SYNTAX. It does NOT execute commands, so it cannot
# detect missing interfaces, duplicate firewall rules, IP collisions, or
# cross-field semantic problems. LLMs that gate "safe to apply" decisions on
# dry-run success will deploy broken configurations.
# ✗ WRONG:
# # Trusting dry-run = "no errors" => safe to apply
# :onerror e in={
#   /import file-name="risky.rsc" verbose=yes dry-run;
# } do={ :error "stop"; }
# /import file-name="risky.rsc";   # NO! dry-run only checked syntax
# ✓ CORRECT — dry-run is a syntax pre-check; ALWAYS combine with safe-mode and
# explicit post-condition verification:
/safe-mode take on-error=unroll;
/import file-name="risky.rsc" verbose=yes;
# Verify post-conditions (interface up, route added, etc.)
:if ($postConditionGood) do={ /safe-mode release; } else={ /safe-mode unroll; }

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 100. EXPECTING SCRIPT-LEVEL :error TO ABORT SAFE-MODE AUTO-COMMIT (7.18+)   │
# └─────────────────────────────────────────────────────────────────────────────┘

# In non-PTY scripted contexts, the 7.18+ safe-mode handler always auto-UNROLLS
# pending changes when the script terminates without an explicit
# /safe-mode release. Even on-error=release does NOT change this — the
# on-error= parameter only governs TRUE network/session disconnects, NOT
# graceful script ends.
# ✗ WRONG:
# /safe-mode take on-error=release;
# /ip firewall filter add chain=input action=accept;
# # script ends here, expecting changes to commit because on-error=release
# # REALITY: handler unrolls, changes are gone
# ✓ CORRECT — explicit /safe-mode release REQUIRED to commit in scripts:
/safe-mode take on-error=unroll;
/ip firewall filter add chain=input action=accept;
/safe-mode release;

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 101. RELYING ON :onerror TO CATCH RELEASE/UNROLL ON INACTIVE SAFE-MODE      │
# └─────────────────────────────────────────────────────────────────────────────┘

# /safe-mode release and /safe-mode unroll on an inactive safe-mode session
# print "Safe Mode has not been taken. Action aborted." but do NOT raise a
# catchable error. :onerror's do={} body does NOT execute; the next statement
# runs normally. LLMs that wrap release in :onerror to "handle already-released
# state" are writing dead code.
# ✗ WRONG:
# :onerror e in={ /safe-mode release; } do={ :put "never runs"; }
# ✓ CORRECT — guard with /safe-mode get enabled, OR ignore the harmless message:
:if ([/safe-mode get enabled]) do={ /safe-mode release; }
# OR: just call release and rely on execution continuing past the message.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ 102. ASSUMING /system script run BOUNDARY ENDS SAFE-MODE                    │
# └─────────────────────────────────────────────────────────────────────────────┘

# /system script run does NOT spawn a separate session. Safe-mode taken inside
# the inner script is INHERITED by the calling session and persists after the
# script-run returns. Inner scripts that take but don't release LEAK safe-mode
# up to the caller.
# ✗ WRONG:
# /system script add name="inner" source={
#   /safe-mode take on-error=unroll;
#   /interface ether set ether1 comment="X";
# }
# /system script run inner;
# :put [/safe-mode get enabled];           # => true (caller still in safe-mode!)
# ✓ CORRECT — inner script must release explicitly, OR caller must own safe-mode:
/system script add name="inner" source={
  /safe-mode take on-error=unroll;
  /interface ether set ether1 comment="X";
  /safe-mode release;                       # always release in inner scripts
}
/system script run inner;

