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
# │ 6. :execute SYNTAX - NO script= PARAMETER                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :execute script=":put test";

# ✓ CORRECT - Script is first positional argument:
:execute ":put test";

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
# │ 13. :execute script= PARAMETER DOES NOT EXIST                               │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :execute script=":put test";

# ✓ CORRECT - First positional argument:
:execute ":put test";

# Exception: as-string version uses script=
:local result [:execute script=":put \"test\"" as-string];

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
# │ 17. :tobool "yes" RETURNS nil, NOT true                                     │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG:
# :if ([:tobool "yes"]) do={ :put "works"; }  # Never executes!

# ✓ CORRECT - Use numeric input:
:put [:tobool 1];                     # => true
:put [:tobool 0];                     # => false

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
# │ 19. [:typeof function] RETURNS "array", NOT "code"                           │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG assumption:
# :if ([:typeof $fn] = "code") do={ ... }  # Never true!

# ✓ CORRECT:
:global fn do={ :return 1; };
:if ([:typeof $fn] = "array") do={ :put "is-function"; };

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
# │ 25. :break AND :continue DO NOT EXIST!                                      │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - These commands do not exist:
# :for i from=1 to=10 do={ :if ($i = 5) do={ :break; }; };
# Result: "bad command name break"

# ✓ CORRECT - Use flag variable workaround:
:local exitLoop false;
:for i from=1 to=10 do={
  :if (!$exitLoop) do={
    :if ($i = 5) do={ :set exitLoop true; };
    # Your code here
  };
};

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
# ✗ WRONG:
# :global myFn do={ :return; };  # ERROR: missing value(s) of argument(s)

# ✓ CORRECT:
:global myFn do={ :return ""; };        # Empty string

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
# │ 30. :for with from>to STILL EXECUTES (WRAPS!)                               │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG assumption that this runs 0 times:
# :for i from=10 to=5 do={}  # Actually runs 6 times (wraps to max)!

# ✓ CORRECT - Check direction or use step=-1:
:for i from=10 to=5 step=-1 do={ };     # Correct countdown

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
# │ 47. :execute ERRORS ARE ISOLATED - PARENT CANNOT CATCH!                     │
# └─────────────────────────────────────────────────────────────────────────────┘
# ✗ WRONG - Assuming parent catches:
:local caught false;
:onerror e in={
  [:execute ":error \"child-error\"" as-string];
} do={
  :set caught true;
};
# caught = false! Errors are ISOLATED!

# ✓ CORRECT - Use globals or file for status

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
# │ 50. :parse RETURNS code TYPE                                                │
# └─────────────────────────────────────────────────────────────────────────────┘
:global myFn [:parse ":put \"hello\""];
:put [:typeof $myFn];                   # => code (not str!)

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
