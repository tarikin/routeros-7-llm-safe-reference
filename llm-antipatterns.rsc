# RouterOS 7 LLM Anti-Patterns Reference
# ══════════════════════════════════════════════════════════════════════════════
# VERIFIED PITFALLS: Errors discovered through empirical testing on RouterOS 7.21rc2
# These are NOT obvious from reading mini-ref.rsc - LLM training data gaps.
# ══════════════════════════════════════════════════════════════════════════════

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
