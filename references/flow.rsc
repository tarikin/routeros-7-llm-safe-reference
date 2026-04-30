# RouterOS 7 Flow Control Reference
# VERIFIED on RouterOS 7.21+ baseline; 7.22+ additions marked inline
# This document contains ONLY empirically verified behavior

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      1. CONDITIONAL: :if/:else                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 1.1: Basic :if syntax
:if (condition) do={ };                 # Single branch
:if (condition) do={ } else={ };        # With else

# RULE 1.2: NO :elseif - Use nested :if in else
:local x 2;
:if ($x = 1) do={
  :put "x is 1";
} else={
  :if ($x = 2) do={
    :put "x is 2";
  } else={
    :put "x is other";
  };
};

# RULE 1.3: Condition MUST be boolean - strings cause ERROR!
# :if ("text") do={ }                   # ERROR: "conditional is not boolean"
:if (true) do={ };                      # OK
:if (1) do={ };                         # OK - numbers coerce (1=true, 0=false)
:if (0) do={ };                         # OK - evaluates to false

# RULE 1.4: :if block can return value (ternary pattern)
:local result [:if (true) do={ :return "yes"; } else={ :return "no"; }];

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      2. LOOP: :for                                          │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 2.1: Basic :for syntax (INCLUSIVE range)
:for i from=1 to=5 do={ :put $i; };     # Prints 1,2,3,4,5

# RULE 2.2: step parameter
:for i from=0 to=10 step=2 do={ };      # 0,2,4,6,8,10

# RULE 2.3: Negative step for countdown
:for i from=5 to=1 step=-1 do={ };      # 5,4,3,2,1

# RULE 2.4: from > to with positive step STILL EXECUTES (wraps!)
# :for i from=10 to=5 do={ } executes 6 times! (wraps to max)

# RULE 2.5: from = to executes ONCE
:for i from=5 to=5 do={ };              # Executes once with i=5

# RULE 2.6: Iterator variable scope = NOTHING after loop
:for loopVar from=1 to=3 do={ };
:put [:typeof $loopVar];                # => nothing

# RULE 2.7: Modifying iterator inside loop has NO effect on iteration count
:for i from=1 to=3 do={ :set i 999; };  # Still runs 3 times

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      3. LOOP: :foreach                                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 3.1: Iterate over array
:local arr {1;2;3};
:foreach item in=$arr do={ :put $item; };

# RULE 3.2: Iterate over dict (key,value pairs)
:local dict {"a"=1;"b"=2};
:foreach k,v in=$dict do={ :put "$k=$v"; };

# RULE 3.3: Empty array = zero iterations (no error)
:foreach x in=[] do={ };                # No iterations

# RULE 3.4: Iterator scope = NOTHING after loop
:foreach loopItem in={1;2} do={ };
:put [:typeof $loopItem];               # => nothing

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      4. LOOP: :while                                        │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 4.1: Pre-test loop (condition checked BEFORE execution)
:local i 0;
:while ($i < 5) do={ :set i ($i + 1); };

# RULE 4.2: False condition = zero iterations
:while (false) do={ };                  # Never executes

# RULE 4.3: Complex conditions work
:while ($x < 5 && $y > 0) do={ };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      5. LOOP: :do {} while=()                               │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 5.1: Post-test loop (executes AT LEAST ONCE)
:local counter 0;
:do {
  :set counter ($counter + 1);
} while=($counter < 5);

# RULE 5.2: CRITICAL - Runs at least once even with false condition!
:local atLeastOnce 0;
:do { :set atLeastOnce 1; } while=(false);
# atLeastOnce = 1 (executed once!)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      6. :break / :continue - WORK ON 7.22+                  │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 6.1: :break exits the innermost :for / :foreach / :while early
:for i from=1 to=10 do={
  :if ($i = 5) do={ :break; };
  :put $i;                              # Prints 1,2,3,4
};

# RULE 6.2: :continue skips to the next iteration
:for i from=1 to=5 do={
  :if ($i = 3) do={ :continue; };
  :put $i;                              # Prints 1,2,4,5
};

# RULE 6.3: Both work inside :foreach
:local arr {10;20;30;40;50};
:foreach v in=$arr do={
  :if ($v > 30) do={ :break; };
  :put $v;                              # Prints 10,20,30
};

# RULE 6.4: In nested loops, :break / :continue affect ONLY the innermost loop
:for i from=1 to=2 do={
  :for j from=1 to=3 do={
    :if ($j = 2) do={ :break; };        # exits inner loop only
    :put ($i . "," . $j);               # Prints 1,1 ; 2,1
  };
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      7. :return                                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 7.1: :return in function returns value
:global myFn do={ :return "result"; };
:put [$myFn];                           # => result

# RULE 7.2: :return preserves type
:global fnNum do={ :return 123; };      # => num
:global fnStr do={ :return "text"; };   # => str
:global fnArr do={ :return {1;2}; };    # => array

# RULE 7.3: :return without value RAISES "missing value of argument" error
# Empirically verified on 7.23rc2: bare :return; (in fn, in :do block, in :if
# branch, in :foreach, in :onerror handler, top-level) all raise:
#   Script Error: missing value(s) of argument(s) value (:return; line N)
# The 7.17 changelog note "console - execute :return command without error"
# refers to a narrower internal fix; bare :return; is STILL a runtime error
# under all script-execution contexts tested (import, /system script run,
# scheduler-equivalent). Use :return ""; or :return value="" for empty exit.
# :return;                              # ERROR (all versions through 7.23rc2)
:return "";                             # Use empty string instead
# Equivalent named-argument form (returns str ""):
:global fnReturnEmpty do={ :return value=""; };

# RULE 7.4: :return in :if block for ternary pattern
:local x [:if ($cond) do={ :return "a"; } else={ :return "b"; }];

# RULE 7.5: :return is CATCHABLE — bare :return; raises a runtime error
# that :onerror can capture (the error type is the same "missing value"
# class as any other runtime error in 7.x):
:global fnBareReturn do={ :return; };
:onerror e in={ [$fnBareReturn]; } do={
  :put $e;                              # captures: missing value(s) of argument(s) value...
};

# RULE 7.6: :return X at top level (NOT inside a fn) raises X as the error
# message — RouterOS treats :return at script-top as throw-with-value:
# :return "early";                      # Script Error: early (:import; line 1)
# Use :return only INSIDE :global/:local fn definitions; otherwise prefer
# :error "msg"; (catchable) or :exit; (silent termination, 7.22+).

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      8. :error / :quit / :exit                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 8.1: :error throws catchable exception
:onerror e in={ :error "my-message"; } do={ :put $e; };

# RULE 8.2: Error message includes source info
# e.g., "my-message (:error; line 18)"

# RULE 8.3: :quit terminates script (NOT catchable, prints "interrupted" to stdout)
# :quit;                                # Script stops; "interrupted" appears on stdout

# RULE 8.4: :exit terminates script (NOT catchable, SILENT) — 7.22+
# Same blast radius as :quit (whole script), no "interrupted" output, takes NO argument.
# Parse error: :exit "msg" / :exit 1   (must be bare :exit;)
# :onerror cannot catch :exit (it is not an error condition).
# :exit inside :foreach / :while terminates the WHOLE script — use :break for loop-only.
# :exit inside :execute child does NOT kill the parent.
# :exit;                                # Script stops; nothing printed

# RULE 8.5: termination primitives compared
# ┌──────────┬──────────────────────────────────────────────────────────────────┐
# │ :error   │ Catchable via :onerror; raises a runtime error condition         │
# │ :quit    │ Terminates script; prints "interrupted"; not catchable           │
# │ :exit    │ 7.22+; terminates script silently; not catchable; no argument    │
# │ :return  │ Exits current function only, with required value                 │
# │ :break   │ 7.22+; exits innermost :for/:foreach/:while only                 │
# │ :continue│ 7.22+; skips to next loop iteration                              │
# └──────────┴──────────────────────────────────────────────────────────────────┘

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      9. :onerror ERROR HANDLING                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 9.1: :onerror syntax
:onerror errorVar in={
  # code that might fail
} do={
  # error handler (errorVar contains message)
};

# RULE 9.2: :onerror RETURNS BOOLEAN!
:local hadError [:onerror e in={ :error "test"; } do={}];
:put $hadError;                         # => true

:local noError [:onerror e in={ :put "ok"; } do={}];
:put $noError;                          # => false

# RULE 9.3: Alternative syntax with :do on-error
:do {
  :error "test";
} on-error={
  :put "caught";
};

# RULE 9.4: Syntax errors CANNOT be caught (parse-time, not runtime)
# :onerror e in={ :nonexistent-cmd } do={}  # Parse error, script fails!

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      10. :retry COMMAND                                     │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 10.1: :retry syntax (inside :onerror)
:onerror e in={
  :retry command={
    # code to retry
  } delay=1 max=3 on-error={
    # called after max retries exceeded
  };
} do={};

# RULE 10.2: Parameters
# command={} - code to execute
# delay=N    - seconds between retries
# max=N      - maximum retry attempts
# on-error={} - callback when max exceeded

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      11. EDGE CASES                                         │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 11.1: Short-circuit evaluation DOES NOT WORK!
# In (true || [$fn]), the function IS STILL CALLED!
:global scCounter 0;
:global scFn do={ :global scCounter; :set scCounter ($scCounter + 1); :return true; };
:if (true || [$scFn]) do={ };           # scCounter = 1 (fn was called!)

# RULE 11.2: Recursion works
:global factorial do={
  :global factorial;
  :if ($1 <= 1) do={ :return 1; };
  :return ($1 * [$factorial ($1 - 1)]);
};
:put [$factorial 5];                    # => 120

# RULE 11.3: Function call in condition works
:global check do={ :return ($1 > 5); };
:if ([$check 10]) do={ :put "big"; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      12. LOOP-LEVEL ON-ERROR (7.19+)                        │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 12.1: :foreach and :for accept on-error={...} (7.19+)
# Default semantic: CONTINUE — after the handler runs, the loop iterates the next item.
# Handler runs ONLY when the body raises an error; never on a clean iteration.
:foreach i in=({1;2;3}) do={
  :if ($i = 2) do={ :error "boom"; };
  :put ("body " . $i);
} on-error={ :put ("handler at " . $i); };
# => body 1
# => handler at 2
# => body 3        (loop continued past the error!)

# RULE 12.2: :for on-error= mirrors :foreach
:for i from=1 to=5 do={
  :if ($i = 3) do={ :error "fail"; };
  :put ("for " . $i);
} on-error={ :put ("err i=" . $i); };

# RULE 12.3: :while does NOT accept on-error= (parse error). Use outer :onerror.
# :while ($x < 5) do={ ... } on-error={ ... };          # Script Error: syntax error

# RULE 12.4: :do {} while=() on-error={...} INHERITS the :do{} try/catch shape, NOT the
# new continue-on-error loop semantics. Handler fires once, loop ABORTS.
:local k 0;
:do {
  :set k ($k + 1);
  :if ($k = 2) do={ :error "stop"; };
  :put ("do " . $k);
} while=($k < 4) on-error={ :put ("do-handler k=" . $k); };
# => do 1
# => do-handler k=2          (loop terminated; k=3,4 never reached)

# RULE 12.5: Error message is NOT bound in the handler — there is NO $err / $e / $errVar.
# Named-binding syntaxes ALL fail at parse time. Handler is fire-and-forget; only the loop
# iterator (and outer locals/globals) are visible.
:foreach i in=({1;2}) do={ :error "boom"; } on-error={
  # $err, $e, $errVar, $error, $errstr, $message — all empty/nothing
  :put ("typeof i=" . [:typeof $i]);    # => num  (loop iterator IS visible)
};

# RULE 12.6: To propagate the error, re-raise via :error inside the handler
:onerror outer in={
  :foreach i in=({1;2;3}) do={
    :if ($i = 2) do={ :error "primary"; };
  } on-error={
    :error ("rethrown at " . [:tostr $i]);
  };
} do={ :put ("outer caught: " . $outer); };
# => outer caught: rethrown at 2 (:error; line N)

# RULE 12.7: Outer :onerror does NOT see the error if the handler doesn't re-raise
:onerror outer in={
  :foreach i in=({1;2}) do={ :error "boom"; } on-error={ :put "consumed"; };
} do={ :put "NEVER PRINTED"; };
# => consumed                (outer's do={} body never runs)

# RULE 12.8: :break inside on-error= exits the loop after the handler
:foreach i in=({1;2;3;4;5}) do={
  :if ($i = 3) do={ :error "x"; };
  :put ("body " . $i);
} on-error={ :put ("stop at " . $i); :break; };
# => body 1, body 2, "stop at 3"  — body 4/5 never run

# RULE 12.9: :return inside on-error= exits the enclosing function
:local fn do={
  :foreach i in=({1;2;3}) do={
    :if ($i = 2) do={ :error "x"; };
  } on-error={ :return "stopped"; };
  :return "ran-to-end";
};
:put [$fn];                             # => stopped

# RULE 12.10: Multiple errors in one loop fire the handler EACH time (default-continue)
:local cnt 0;
:foreach i in=({1;2;3;4;5}) do={
  :if (($i = 2) || ($i = 4)) do={ :error "x"; };
} on-error={ :set cnt ($cnt + 1); };
:put ("errors: " . $cnt);               # => errors: 2

# RULE 12.11: Built-in command errors (not just :error) are caught
:foreach name in=({"nonexistent-iface-xyz"}) do={
  /interface get $name name;
} on-error={ :put ("missing iface: " . $name); };

# RULE 12.12: :foreach k,v with on-error: BOTH $k and $v visible in handler
:local d ({a=1;b=2;c=3});
:foreach k,v in=$d do={
  :if ($v = 2) do={ :error "x"; };
} on-error={ :put ("handler k=" . $k . " v=" . $v); };

# RULE 12.13: Parameter ORDER is flexible — on-error= may come before or after do=
:foreach i in=({1;2}) on-error={ :put "h"; } do={ :error "x"; };

# RULE 12.14: NEWLINE between } and on-error= is a parse error
# :foreach i in={1} do={...}\n on-error={...};        # Script Error: syntax error
# Keep the construct on a single logical line.

# RULE 12.15: Empty handler suppresses errors silently
:foreach i in=({1;2;3}) do={
  :if ($i = 2) do={ :error "x"; };
  :put ("body " . $i);
} on-error={ };                          # legal; consumes errors with no side-effect
# => body 1, body 3

# RULE 12.16: STRICT ARGUMENT VALIDATION (7.19+)
# do= and on-error= now REQUIRE an inline {...} literal at the parse site. Indirection via
# variable — even when the variable holds a valid block — is REJECTED.
# :local fn do={ :put "x"; };
# :foreach i in=({1;2}) do=$fn;                       # Script Error: invalid value for argument do
# :if (true) do=$fn;                                  # same
# :foreach i in=({1;2}) do={...} on-error=$h;         # Script Error: invalid value for argument on-error
# Workaround: keep the block inline; if reusable, call a global function from inside it:
:global handler do={ :put ("h: " . $1); };
:foreach i in=({1;2}) do={
  :if ($i = 2) do={ :error "x"; };
} on-error={ [$handler $i]; };

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      QUICK REFERENCE TABLE                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌────────────────────┬─────────────────────────────────────────────────────────┐
# │ Construct          │ Notes                                                   │
# ├────────────────────┼─────────────────────────────────────────────────────────┤
# │ :if/:else          │ NO :elseif, nest :if in else block                      │
# │ :for               │ from/to INCLUSIVE, step defaults to 1                   │
# │ :foreach           │ k,v for dicts, empty array = zero iterations            │
# │ :while             │ Pre-test, condition before execution                    │
# │ :do while          │ Post-test, AT LEAST ONCE execution                      │
# │ :break             │ Exits :for/:foreach/:while early (7.22+)                │
# │ :continue          │ Skips to next iteration (7.22+)                         │
# │ :return            │ Bare :return; raises "missing value" error (all ver-    │
# │                    │ sions); use :return ""; / :return value=""; for empty   │
# │ :error             │ Catchable exception                                     │
# │ :quit              │ NOT catchable, terminates script (prints "interrupted") │
# │ :exit              │ NOT catchable, terminates script silently (7.22+)       │
# │ :onerror           │ Returns bool, catches runtime errors only               │
# │ :retry             │ Must be inside :onerror block                           │
# │ :foreach on-error= │ 7.19+; default = CONTINUE; no error variable bound;     │
# │ :for on-error=     │ :while is NOT supported; :do/while uses try/catch shape │
# └────────────────────┴─────────────────────────────────────────────────────────┘
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ CRITICAL LLM PITFALLS                                                        │
# ├──────────────────────────────────────────────────────────────────────────────┤
# │ ✓ :break and :continue WORK on 7.22+ (innermost loop only)                   │
# │ ✗ :elseif DOES NOT EXIST (use nested :if in else)                            │
# │ ✗ switch/case DOES NOT EXIST                                                 │
# │ ✗ goto DOES NOT EXIST                                                        │
# │ ✗ :return without value still raises "missing value" error on 7.23rc2 —      │
# │   use :return ""; or :return value=""; (catchable via :onerror)              │
# │ ✗ String in condition is ERROR ("conditional is not boolean")                │
# │ ✗ Short-circuit evaluation DOES NOT WORK                                     │
# │ ✗ Syntax errors cannot be caught by :onerror                                 │
# │ ✗ :quit is NOT catchable                                                     │
# │ ✗ :exit is NOT catchable, NOT a loop primitive — use :break for loop-only    │
# │ ✗ :exit accepts NO argument; :exit "msg" / :exit 1 are parse errors          │
# │ ✗ :for with from>to STILL EXECUTES (wraps!)                                  │
# │ ✗ :foreach/:for on-error={} default = CONTINUE (NOT catch-and-stop) — 7.19+  │
# │ ✗ on-error={} handler does NOT bind error msg ($err/$e/$errVar all empty)    │
# │ ✗ on-error={} SUPPRESSES error from outer :onerror (use :error to re-raise)  │
# │ ✗ :while does NOT support on-error= (only :foreach and :for do)              │
# │ ✗ :do/while on-error={} keeps OLD try/catch shape (one-shot exit, NOT cont)  │
# │ ✗ do=$var / on-error=$var REJECTED on 7.19+ (require inline {...} literal)   │
# └──────────────────────────────────────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+ baseline; 7.22+ additions inline
# ══════════════════════════════════════════════════════════════════════════════
