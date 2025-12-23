# RouterOS 7 Flow Control Reference
# VERIFIED on RouterOS 7.21+
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
# │                      6. :break/:continue - DO NOT EXIST!                    │
# └─────────────────────────────────────────────────────────────────────────────┘

# CRITICAL: RouterOS does NOT have :break or :continue commands!
# Attempting to use them results in: "bad command name break"

# WORKAROUND - Use flag variables:
:local exitLoop false;
:for i from=1 to=100 do={
  :if (!$exitLoop) do={
    :if ($i = 10) do={ :set exitLoop true; };
    # ... your code here (only runs if not exiting)
  };
};

# WORKAROUND - Use :while with exit condition:
:local searching true;
:local idx 0;
:while ($searching && $idx < [:len $arr]) do={
  :if (($arr->$idx) = $target) do={ :set searching false; };
  :set idx ($idx + 1);
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

# RULE 7.3: :return without value = ERROR!
# :return;                              # ERROR: missing value(s) of argument(s)
:return "";                             # Use empty string instead

# RULE 7.4: :return in :if block for ternary pattern
:local x [:if ($cond) do={ :return "a"; } else={ :return "b"; }];

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      8. :error / :quit                                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 8.1: :error throws catchable exception
:onerror e in={ :error "my-message"; } do={ :put $e; };

# RULE 8.2: Error message includes source info
# e.g., "my-message (:error; line 18)"

# RULE 8.3: :quit terminates script (NOT catchable!)
# :quit;                                # Script stops completely

# RULE 8.4: :error vs :quit
# :error = catchable with :onerror
# :quit  = NOT catchable, terminates immediately

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
# │ :break             │ DOES NOT EXIST! Use flag variables                      │
# │ :continue          │ DOES NOT EXIST! Use flag variables                      │
# │ :return            │ MUST have value, use "" for empty                       │
# │ :error             │ Catchable exception                                     │
# │ :quit              │ NOT catchable, terminates script                        │
# │ :onerror           │ Returns bool, catches runtime errors only               │
# │ :retry             │ Must be inside :onerror block                           │
# └────────────────────┴─────────────────────────────────────────────────────────┘
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ CRITICAL LLM PITFALLS                                                        │
# ├──────────────────────────────────────────────────────────────────────────────┤
# │ ✗ :break and :continue DO NOT EXIST                                          │
# │ ✗ :elseif DOES NOT EXIST (use nested :if in else)                            │
# │ ✗ switch/case DOES NOT EXIST                                                 │
# │ ✗ goto DOES NOT EXIST                                                        │
# │ ✗ :return without value is ERROR                                             │
# │ ✗ String in condition is ERROR ("conditional is not boolean")                │
# │ ✗ Short-circuit evaluation DOES NOT WORK                                     │
# │ ✗ Syntax errors cannot be caught by :onerror                                 │
# │ ✗ :quit is NOT catchable                                                     │
# │ ✗ :for with from>to STILL EXECUTES (wraps!)                                  │
# └──────────────────────────────────────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+
# ══════════════════════════════════════════════════════════════════════════════
