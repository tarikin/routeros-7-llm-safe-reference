# RouterOS 7 Error Handling Reference
# VERIFIED on RouterOS 7.21+
# This document contains ONLY empirically verified behavior from 400+ tests

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      1. :onerror SYNTAX                                     │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 1.1: Basic :onerror syntax
:onerror errorVar in={
  # code that might fail
} do={
  # error handler ($errorVar contains error message)
};

# RULE 1.2: :onerror RETURNS BOOLEAN!
:local hadError [:onerror e in={ :error "test"; } do={}];
:put $hadError;                         # => true

:local noError [:onerror e in={ :put "ok"; } do={}];
:put $noError;                          # => false

# RULE 1.3: Error variable type = str
# Error message format: "message (:error; line N)"

# RULE 1.4: Custom error variable names work
:onerror myErr in={ :error "x"; } do={ :put [:typeof $myErr]; };
:onerror e in={ :error "x"; } do={ :put $e; };       # Short name OK
# :onerror _ in={} do={}  # UNDERSCORE NOT VALID!

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      2. :do on-error ALTERNATIVE                            │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 2.1: Alternative syntax (simpler, no error variable)
:do {
  :error "test";
} on-error={
  # handler has NO error variable by default!
};

# RULE 2.2: Combine while= and on-error=
:local i 0;
:do {
  :set i ($i + 1);
  :if ($i = 3) do={ :error "stop"; };
} on-error={} while=($i < 5);           # Stops at 3

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      3. :error COMMAND                                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 3.1: Throw catchable error
:error "my-message";

# RULE 3.2: Error message format includes source info
# Output: "my-message (:error; line 18)"

# RULE 3.3: Multiple :error - only first is thrown
:onerror e in={
  :error "first";
  :error "second";    # Never reached
} do={};

# RULE 3.4: Error in function propagates to caller
:global myFn do={ :error "from-fn"; };
:onerror e in={ [$myFn]; } do={ :put "caught"; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      4. :quit TERMINATION                                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 4.1: :quit is NOT catchable!
# :onerror e in={ :quit; } do={}        # Script TERMINATES!

# RULE 4.2: :quit vs :error
# :error = catchable, script continues after handler
# :quit  = NOT catchable, script terminates immediately

# RULE 4.3: Use :error for catchable exit
:onerror e in={
  :if (condition) do={ :error "exit-early"; };
} do={};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      5. :retry COMMAND                                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 5.1: :retry syntax (inside :onerror)
:onerror e in={
  :retry command={
    # code to retry
  } delay=1 max=3 on-error={
    # called after max retries exceeded
  };
} do={};

# RULE 5.2: Success stops retries
:global attempt 0;
:onerror e in={
  :retry command={
    :global attempt;
    :set attempt ($attempt + 1);
    :if ($attempt < 3) do={ :error "retry"; };
    # Success on 3rd attempt - stops retrying
  } delay=0 max=5;
} do={};
# attempt = 3

# RULE 5.3: max=0 = zero retries (code not executed)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      6. CATCHABLE ERRORS                                    │
# └─────────────────────────────────────────────────────────────────────────────┘

# CATCHABLE (runtime errors):
# - :error "message"
# - Division by zero (1/0)
# - :resolve DNS failure
# - /tool fetch failure
# - /ip address add (invalid interface)
# - /ip route add (invalid gateway)
# - /file get (nonexistent file)
# - /import (missing file)
# - String + number arithmetic

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      7. NOT CATCHABLE - CRITICAL!                           │
# └─────────────────────────────────────────────────────────────────────────────┘

# NOT CATCHABLE:
# - Syntax errors (parse-time, script fails to load)
# - :quit (terminates script)
# - Bad command name (parse error)
# - Undefined variable at parse time
# - Missing required parameters

# NOT AN ERROR (returns nil/empty, no exception):
# - Array out of bounds ($arr->99)
# - Nil addition ($nilVar + 1)
# - Dict key miss ($dict->"nonexistent")
# - Empty find result [/interface find name="xyz"]
# - Print no match /interface print where name="xyz"
# - Remove empty find /file remove []

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      8. NESTED ERROR HANDLING                               │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 8.1: Inner handler catches, outer doesn't see
:onerror outer in={
  :onerror inner in={
    :error "x";
  } do={
    :put "inner catches";
  };
} do={
  :put "outer never called";
};

# RULE 8.2: Re-throw from inner to outer
:onerror outer in={
  :onerror inner in={
    :error "original";
  } do={
    :error "re-thrown";       # Outer catches this
  };
} do={
  :put "outer catches re-throw";
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      9. :execute ERROR HANDLING                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 9.1: :execute errors are ISOLATED - NOT caught by parent!
:local caught false;
:onerror e in={
  [:execute ":error \"exec-error\"" as-string];
} do={
  :set caught true;
};
# caught = false! Execute is isolated!

# RULE 9.2: :execute returns job ID (async) or output (as-string)
:local jobId [:execute ":put 123"];        # Returns ID (async)
:local output [:execute ":put 456" as-string];  # Returns "456\n" (sync)

# RULE 9.3: :execute can modify global variables
:global myGlobal "original";
[:execute ":global myGlobal; :set myGlobal \"modified\"" as-string];
# myGlobal = "modified"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      10. ERROR IN LOOPS                                     │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 10.1: :onerror OUTSIDE loop = loop stops
:local count 0;
:onerror e in={
  :for i from=1 to=5 do={
    :set count ($count + 1);
    :if ($i = 3) do={ :error "stop"; };
  };
} do={};
# count = 3 (loop stopped)

# RULE 10.2: :onerror INSIDE loop = continue pattern
:local count 0;
:for i from=1 to=5 do={
  :onerror e in={
    :if ($i = 3) do={ :error "skip"; };
    :set count ($count + 1);
  } do={};
};
# count = 4 (skipped i=3, continued)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      11. SHORT-CIRCUIT DOESN'T WORK!                        │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 11.1: All conditions are evaluated (no short-circuit)
:global callCount 0;
:global myFn do={ :global callCount; :set callCount ($callCount + 1); :return true; };
:if (true || [$myFn]) do={};            # callCount = 1 (fn WAS called!)

# RULE 11.2: For short-circuit, use nested :if
:if (true) do={} else={ :if ([$myFn]) do={}; };  # Correct pattern

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      QUICK REFERENCE TABLE                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌────────────────────┬─────────────────────────────────────────────────────────┐
# │ Construct          │ Notes                                                   │
# ├────────────────────┼─────────────────────────────────────────────────────────┤
# │ :onerror           │ Returns bool, error var = string, catches runtime only  │
# │ :do on-error       │ Alternative syntax, NO error variable                   │
# │ :error             │ Throw catchable exception                               │
# │ :quit              │ NOT catchable, terminates script                        │
# │ :retry             │ Inside :onerror, max=0 = no execution                   │
# │ :execute           │ Errors ISOLATED, async by default                       │
# └────────────────────┴─────────────────────────────────────────────────────────┘
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ CRITICAL LLM PITFALLS                                                        │
# ├──────────────────────────────────────────────────────────────────────────────┤
# │ ✗ :return; without value HANGS ("value:" prompt)                             │
# │ ✗ :execute errors are ISOLATED - parent cannot catch                         │
# │ ✗ :quit is NOT catchable                                                     │
# │ ✗ Syntax errors cannot be caught by :onerror                                 │
# │ ✗ Array out-of-bounds returns nil, NOT an error                              │
# │ ✗ Dict key miss returns "nothing", NOT an error                              │
# │ ✗ Empty find result is NOT an error                                          │
# │ ✗ Short-circuit evaluation DOES NOT WORK                                     │
# │ ✗ :do on-error has NO error variable                                         │
# │ ✗ Underscore _ is NOT a valid variable name                                  │
# │ ✗ :onerror parameter order is critical (e in={} do={})                       │
# └──────────────────────────────────────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+
# ══════════════════════════════════════════════════════════════════════════════
