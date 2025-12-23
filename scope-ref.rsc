# RouterOS 7 Variable Scoping Reference
# VERIFIED on RouterOS 7.21+
# This document contains ONLY empirically verified behavior

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         1. BASIC SCOPING RULES                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 1.1: Locals are block-scoped
# A :local variable is only accessible within its declaring block and nested blocks.
{
  :local a "hello"; # Declared in this block
  :put $a;          # Works: "hello"
  {
    :put $a;        # Works: inner block inherits outer scope
  }
}
# :put $a;          # Would fail: $a out of scope here

# RULE 1.2: Sibling blocks are isolated
# Variables in one block are NOT accessible in sibling blocks.
{
  { :local b "first"; }
  # :put $b;        # Fails: $b was scoped to the first block only
}

# RULE 1.3: Shadowing works correctly
# Inner blocks can shadow outer variables; outer values restore after inner exits.
{
  :local x "outer";
  :put $x;          # => "outer"
  {
    :local x "shadowed";
    :put $x;        # => "shadowed"
  }
  :put $x;          # => "outer" (restored after inner block exits)
}

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         2. GLOBAL VS LOCAL                                  │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 2.1: Locals shadow globals within their scope
:global gVar "global-value";
{
  :local gVar "local-shadow";
  :put $gVar;       # => "local-shadow"
}
:put $gVar;         # => "global-value" (global unchanged)

# RULE 2.2: Globals modified in nested blocks persist
:global gMod "original";
{
  { :set gMod "modified-deep"; }
}
:put $gMod;         # => "modified-deep"

# RULE 2.3: Globals declared inside blocks are accessible outside
# NOTE: Must re-declare with :global before access outside the block
{
  :global gInside "born-inside";
}
:global gInside;    # Must re-declare to access
:put $gInside;      # => "born-inside"

# RULE 2.4: :set modifies the INNERMOST binding (local or global)
:global gTest "g1";
{
  :local gTest "l1";
  :set gTest "modified"; # Modifies the LOCAL, not the global
  :put $gTest;      # => "modified" (local)
}
:put $gTest;        # => "g1" (global unchanged)

# RULE 2.5: :set on undeclared variable is a PARSE-TIME error
# Cannot use :set without prior :global or :local declaration.
# This error occurs at parse time, not runtime.

# RULE 2.6: Accessing undeclared variable returns empty (nothing)
# No runtime error - just returns empty string/nothing.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         3. FUNCTION SCOPE                                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 3.1: Functions have their own scope - NO CLOSURES
# Functions CANNOT access outer :local variables. This is a PARSE-TIME error.
:local outer "exists";
# :global fn do={ :put $outer; };  # PARSE ERROR: outer not in function scope

# RULE 3.2: Functions access globals via re-declaration
:global gFuncTest "start";
:global fnModGlobal do={
  :global gFuncTest;              # Must re-declare global inside function
  :set gFuncTest "modified";
};
$fnModGlobal;
:put $gFuncTest;    # => "modified"

# RULE 3.3: Function parameters are $1, $2, etc.
:global fnParam do={ :put ("param:" . $1); };
$fnParam "value";   # => "param:value"

# RULE 3.4: Nested functions work (local within function)
:global fnOuter do={
  :local innerFn do={ :return "inner-ran"; };
  :return [$innerFn];
};
:put [$fnOuter];    # => "inner-ran"

# RULE 3.5: Functions can return values
:global fnReturn do={ :return "returned-value"; };
:local result [$fnReturn];
:put $result;       # => "returned-value"

# RULE 3.6: Recursive functions work with :global
:global fnRecurse do={
  :global fnRecurse;  # Must re-declare for self-reference
  :if ($1 <= 0) do={ :return "done"; };
  :return ("L" . $1 . "-" . [$fnRecurse ($1 - 1)]);
};
# Note: Recursion depth may be limited

# RULE 3.7: Multiple functions can share globals
:global shared 0;
:global fnA do={ :global shared; :set shared ($shared + 1); };
:global fnB do={ :global shared; :set shared ($shared + 10); };
$fnA; $fnB;
:put $shared;       # => "11"

# RULE 3.8: Closures/higher-order functions are NOT supported
# Returning a do={} block is a PARSE-TIME error.

# RULE 3.9: Function called before definition fails (no hoisting)
# Must define function before calling it.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         4. LOOP SCOPE                                       │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 4.1: Loop iterators do NOT persist after loop
:for i from=1 to=3 do={ };
# :put $i;          # Returns empty - iterator out of scope

:foreach item in={1;2;3} do={ };
# :put $item;       # Returns empty - iterator out of scope

# RULE 4.2: Locals inside loop body don't persist
:for j from=1 to=1 do={
  :local loopLocal "inside";
};
# :put $loopLocal;  # Returns empty - out of scope

# RULE 4.3: Loops CAN modify outer locals
:local sum 0;
:for k from=1 to=5 do={
  :set sum ($sum + $k);
};
:put $sum;          # => "15"

# RULE 4.4: Nested loops with same iterator name shadow correctly
:local result "";
:for i from=1 to=2 do={
  :set result ($result . "O" . $i);
  :for i from=10 to=11 do={
    :set result ($result . "I" . $i);
  };
};
:put $result;       # => "O1I10I11O2I10I11"

# RULE 4.5: Function locals are visible in loops within the function
:global fnWithLoop do={
  :local funcLocal "visible";
  :local res "";
  :for m from=1 to=2 do={
    :set res ($res . $funcLocal . $m);
  };
  :return $res;
};
:put [$fnWithLoop]; # => "visible1visible2"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         5. CONDITIONAL SCOPE                                │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 5.1: Locals in if/else bodies don't persist outside
:if (true) do={
  :local ifLocal "inside-if";
};
# :put $ifLocal;    # Returns empty - out of scope

# RULE 5.2: Mutations to outer locals persist
:local outer5 "before";
:if (true) do={
  :set outer5 "after-if";
};
:put $outer5;       # => "after-if"

# RULE 5.3: Nested conditionals work correctly
:local result5 "";
:if (true) do={
  :local level1 "L1";
  :if (true) do={
    :local level2 "L2";
    :set result5 ($level1 . "-" . $level2);
  };
};
:put $result5;      # => "L1-L2"

# RULE 5.4: Both branches see outer variables
:local shared5 "shared-value";
:local out5 "";
:if (true) do={
  :set out5 ("if:" . $shared5);
} else={
  :set out5 ("else:" . $shared5);
};
:put $out5;         # => "if:shared-value"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         6. DO-WHILE SCOPE                                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 6.1: Locals inside :do body don't persist outside
:local cnt6 0;
:do {
  :set cnt6 ($cnt6 + 1);
  :local bodyLocal "in-body";
} while=($cnt6 < 3);
:put $cnt6;         # => "3"
# :put $bodyLocal;  # Returns empty - out of scope

# RULE 6.2: while=() condition sees updated counter from body
:local iter6 0;
:do {
  :set iter6 ($iter6 + 1);
} while=($iter6 < 5);
:put $iter6;        # => "5"

# RULE 6.3: Nested do-while works correctly
:local outer6 0;
:local total6 0;
:do {
  :set outer6 ($outer6 + 1);
  :local inner6 0;
  :do {
    :set inner6 ($inner6 + 1);
    :set total6 ($total6 + 1);
  } while=($inner6 < 2);
} while=($outer6 < 3);
:put $total6;       # => "6" (3 outer × 2 inner)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         7. COMPLEX SCENARIOS                                │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 7.1: 4 levels of shadowing work correctly
:local x "L0";
{
  :local x "L1";
  {
    :local x "L2";
    {
      :local x "L3";
      :put $x;      # => "L3"
    }
    :put $x;        # => "L2"
  }
  :put $x;          # => "L1"
}
:put $x;            # => "L0"

# RULE 7.2: :onerror handler has its own scope
:onerror errVar in={
  :resolve "invalid.domain.xyz";
} do={
  :local errMsg $errVar;  # errVar is only valid here
  :put "caught-error";
};
# $errMsg not accessible here

# RULE 7.3: :retry command works with globals
:global retryCnt 0;
:onerror e in={
  :retry command={
    :set retryCnt ($retryCnt + 1);
    :if ($retryCnt < 3) do={ :error "retry"; };
  } delay=0 max=5 on-error={ };
} do={ };
:put $retryCnt;     # => "3"

# RULE 7.4: :execute shares global scope
:global execResult "not-set";
:execute ":global execResult \"from-execute\"";
:delay 1s;          # Give execute time to run
:put $execResult;   # => "from-execute"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         8. EDGE CASES & GOTCHAS                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 8.1: Special characters in variable names require quotes
:local "my-var" "hyphenated";
:put $"my-var";     # => "hyphenated"

:local "my_var" "underscored";
:put $"my_var";     # => "underscored"

# RULE 8.2: Numeric prefix in variable name is PARSE ERROR
# :local 1var "test";  # PARSE ERROR

# RULE 8.3: Re-declaration in same scope is ALLOWED - second wins
:local var8 "first";
:local var8 "second";
:put $var8;         # => "second"

# RULE 8.4: Uninitialized :local is type "nothing"
:local uninit;
:put [:typeof $uninit]; # => "nothing"
:put $uninit;           # => empty string

# RULE 8.5: :typeof on out-of-scope variable returns "nothing"
{
  :local scoped "exists";
}
:put [:typeof $scoped]; # => "nothing"

# RULE 8.6: Arguments are passed BY VALUE (not reference)
:local original "unchanged";
:global fnByVal do={
  :local param $1;
  :set param "modified-inside";
  :return $param;
};
:local returned [$fnByVal $original];
:put $original;     # => "unchanged" (not modified)
:put $returned;     # => "modified-inside"

# RULE 8.7: Arrays are mutable across scopes (reference semantics)
:local arr {"a"="alpha"; "b"="beta"};
:put ($arr->"a");   # => "alpha"
{
  :set ($arr->"c") "gamma";
}
:put ($arr->"c");   # => "gamma" (modification persists)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         QUICK REFERENCE SUMMARY                             │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌──────────────────────────────┬───────────────────────────────────────────────┐
# │ Scope Rule                   │ Behavior                                      │
# ├──────────────────────────────┼───────────────────────────────────────────────┤
# │ Block scope                  │ :local visible in block + nested blocks only  │
# │ Sibling isolation            │ Siblings cannot access each other's locals    │
# │ Shadowing                    │ Inner overrides outer; outer restores on exit │
# │ Global transcendence         │ :global visible everywhere (must re-declare)  │
# │ :set binding                 │ Modifies innermost declaration                │
# │ Function isolation           │ Functions cannot access outer :local (no closure) │
# │ Global in function           │ Must :global inside function to access        │
# │ Loop iterator                │ NOT accessible after loop ends                │
# │ Loop/if body locals          │ NOT accessible after block exits              │
# │ Outer mutation in block      │ Modifications to outer :local persist         │
# │ Closures                     │ NOT SUPPORTED (parse error)                   │
# │ Hoisting                     │ NOT SUPPORTED (must define before use)        │
# │ Argument passing             │ By value (primitives) / by reference (arrays) │
# │ Uninitialized                │ Type "nothing", value empty                   │
# │ Special char names           │ Require quotes: :local "my-var" and $"my-var" │
# │ Redeclaration                │ Allowed - second wins                         │
# │ :execute scope               │ Shares :global scope with caller              │
# │ :onerror handler             │ Has own scope for error variable              │
# └──────────────────────────────┴───────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+
# ══════════════════════════════════════════════════════════════════════════════
