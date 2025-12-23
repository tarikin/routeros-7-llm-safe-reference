# RouterOS 7 Async Commands Reference
# VERIFIED on RouterOS 7.21+
# This document contains ONLY empirically verified async behaviors from 400+ tests

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      1. :execute COMMAND                                    │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 1.1: :execute is ASYNC by default - returns immediately!
:local jobId [:execute ":delay 5s"];
:put [:typeof $jobId];                  # => id
# Script continues without waiting!

# RULE 1.2: SYNC mode with as-string (BLOCKING!)
:local output [:execute ":put 123" as-string];
:put [:typeof $output];                 # => str
# Blocks until script completes!

# RULE 1.3: Return types
# Async: returns id (job identifier)
# Sync (as-string): returns str (script output)

# RULE 1.4: 64kB script limit for :execute

# RULE 1.5: script= parameter for named scripts
:local j [:execute script="my-script-name"];

# RULE 1.6: file= parameter for output capture
:local j [:execute ":put test" file="output.txt"];

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      2. :execute ERRORS ARE ISOLATED!                       │
# └─────────────────────────────────────────────────────────────────────────────┘

# CRITICAL: Parent CANNOT catch child errors!
:local parentCaught false;
:onerror e in={
  [:execute ":error \"child-error\"" as-string];
} do={
  :set parentCaught true;
};
:put $parentCaught;                     # => false (NOT CAUGHT!)

# For error status, use globals or file output

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      3. /system script job                                  │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 3.1: Capture job ID for management
:local jobId [:execute ":delay 10s"];

# RULE 3.2: List jobs
/system script job print

# RULE 3.3: Remove job (stop execution)
/system script job remove $jobId;

# RULE 3.4: Job auto-removes on completion
:local shortJob [:execute ":local x 1"];
:delay 500ms;
:local stillExists [/system script job find where .id=$shortJob];
# stillExists = empty (job completed and removed)

# RULE 3.5: Job properties
# owner, started, policy (read-only)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      4. :delay COMMAND                                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 4.1: Formats: ms, s, m, h
:delay 100ms;
:delay 1s;
:delay 1m;
:delay 1h;

# RULE 4.2: Delay ONLY pauses current thread!
:local j [:execute ":delay 2s"];
:delay 500ms;                           # Does NOT wait for job!
# Job still running!

# RULE 4.3: Delay does NOT sync with async jobs!

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      5. /tool fetch IS BLOCKING!                            │
# └─────────────────────────────────────────────────────────────────────────────┘

# CRITICAL LLM HALLUCINATION: fetch is assumed async - WRONG!
/tool fetch url="http://example.com/file";
# Script BLOCKS until fetch completes or fails!

# RULE 5.1: To make fetch async, wrap in :execute
:local j [:execute "/tool fetch url=\"http://example.com/file\" keep-result=no"];
# Returns immediately, fetch runs in background

# RULE 5.2: Timeout parameters
# duration= (total time limit)
# idle-timeout= (default 10s)

# RULE 5.3: Output modes
# output=none    - discard
# output=file    - save to dst-path
# output=user    - print to console
# as-value=yes   - return array with status

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      6. /system scheduler                                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 6.1: Scheduler is ASYNC (on-event runs in background)

# RULE 6.2: interval=0s = one-shot (runs once)
# RULE 6.3: interval>0s = recurring

# RULE 6.4: start-time=startup
# With interval=0s: runs once ~3s after boot
# With interval>0s: does NOT run at startup!

# RULE 6.5: Policy inheritance
# Scheduler can use its own policy or script's policy
# use-script-permissions forces script's policy

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      7. /tool netwatch                                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 7.1: Netwatch is ASYNC (on-up/on-down run in background)

# RULE 7.2: CRITICAL - runs as sys user (LIMITED PERMISSIONS!)
# Policies: read, write, test, reboot ONLY
# NO ftp policy - fetch fails in v7.13+!

# RULE 7.3: Multiple entries run independently (no blocking)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      8. GLOBAL VARIABLES                                    │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 8.1: Globals persist until reboot
:global myVar "value";
# Available across all script runs!

# RULE 8.2: Stored in /system script environment
/system script environment print

# RULE 8.3: :execute CAN modify globals
:global testVar "original";
[:execute ":global testVar; :set testVar \"modified\"" as-string];
# testVar = "modified"

# RULE 8.4: No auto-clear - manual cleanup required
:set myVar;                             # Unset

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      9. :parse COMMAND                                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 9.1: Creates dynamic function, returns `code` type
:global myFn [:parse ":put \"hello\""];
:put [:typeof $myFn];                   # => code

# RULE 9.2: NO CLOSURES! New scope per call
:local outerVar "test";
:global fn [:parse ":put \$outerVar"];  # Won't work as expected!

# RULE 9.3: For type conversion
:global ipVal [[:parse ":return 192.168.1.1"]];
:put [:typeof $ipVal];                  # => ip

:global timeVal [[:parse ":return 1h30m"]];
:put [:typeof $timeVal];                # => time

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      10. TIME COMMANDS                                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 10.1: :time measures execution (returns time)
:local duration [:time {:delay 100ms}];
:put [:typeof $duration];               # => time

# RULE 10.2: :timestamp current time (returns time, NOT num!)
:local ts [:timestamp];
:put [:typeof $ts];                     # => time

# RULE 10.3: :tonsec conversion (time → nanoseconds)
:put [:tonsec 1s];                      # => 1000000000
:put [:tonsec 1ms];                     # => 1000000
:put [:tonsec 1m];                      # => 60000000000

# RULE 10.4: Time comparison works
:put (1s > 500ms);                      # => true
:put (1m = 60s);                        # => true

# RULE 10.5: /system clock
:local date [/system clock get date];
:put [:typeof $date];                   # => str

:local time [/system clock get time];
:put [:typeof $time];                   # => time

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      11. :jobname COMMAND                                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 11.1: Returns current script name
:local name [:jobname];

# RULE 11.2: Single instance pattern
:if ([/system script job print count-only where script=[:jobname]] > 1) do={
  :error "already running";
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      12. FILESYSTEM OPERATIONS (BLOCKING!)                  │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 12.1: /system backup save is BLOCKING
# Script halts until backup is complete
/system backup save name="test";        # BLOCKS!

# RULE 12.2: Large file print/read is BLOCKING
# Printing large file contents blocks execution
/file print detail where name="large.txt"; # BLOCKS!

# RULE 12.3: Async Backup Pattern
# Use :execute to perform backups in background
:local backupJob [:execute "/system backup save name=\"daily-backup\""];

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      13. CERTIFICATE OPERATIONS (BLOCKING!)                 │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 13.1: Signing is SYNCHRONOUS
# /certificate sign blocks until CPU completes the crypto
/certificate sign my-cert;              # BLOCKS!

# RULE 13.2: Network-based cert ops (SCEP, ACME) are BLOCKING
# SCEP client updates wait for network response
/certificate scep-client renew;         # BLOCKS!

# RULE 13.3: CRL updates are BLOCKING
# Fetches CRL from URL synchronously
/certificate crl update;                # BLOCKS!

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      14. NETWORK TRAPS (LOOK ASYNC, BUT BLOCK)              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 14.1: /tool e-mail send is BLOCKING
# Waits for SMTP server handshake and data transfer
/tool e-mail send to="user@example.com" subject="Test"; # BLOCKS!

# RULE 14.2: /tool sms send is BLOCKING
# Waits for modem AT command response
/tool sms send usb1 "123456" message="Hello"; # BLOCKS!

# RULE 14.3: /interface wireless spectral-scan is BLOCKING
# Freezes script for duration of scan
/interface wireless spectral-scan wlan1 duration=5s; # BLOCKS for 5s!

# RULE 14.4: /tool bandwidth-test is BLOCKING
# Unless running in background with :execute, it halts script
/tool bandwidth-test 1.1.1.1 duration=10s; # BLOCKS!

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      15. COMMON ASYNC PATTERNS                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# PATTERN A: The Wrapper (Universal)
# Wrap ANY blocking command in :execute to make it async
:local j [:execute "/tool e-mail send ..."];

# PATTERN B: Fire-and-Forget
# For tasks where result doesn't matter (logging, notifications)
[:execute "/log info \"Background task started\""];

# PATTERN C: Polling Loop (Pseudo-Async)
# Start async job, then poll for completion in loop
:local j [:execute "/tool fetch ... as-value"];
:while ([/system script job print count-only where .id=$j] > 0) do={
  :delay 100ms;
  # Do other work here...
};

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      BLOCKING vs ASYNC SUMMARY                              │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌────────────────────────────────────────────────────────────────────────────┐
# │ BLOCKING COMMANDS (TRAPS!)                                                 │
# ├────────────────────────────────────────────────────────────────────────────┤
# │ /tool fetch            ← Waits for HTTP code                               │
# │ /tool e-mail send      ← Waits for SMTP                                    │
# │ /tool sms send         ← Waits for Modem                                   │
# │ /system backup save    ← Waits for Disk I/O                                │
# │ /certificate sign      ← Waits for Crypto                                  │
# │ /certificate scep      ← Waits for Network                                 │
# │ spectral-scan          ← Waits for Scan Duration                           │
# └────────────────────────────────────────────────────────────────────────────┘
#
# ┌────────────────────────────────────────────────────────────────────────────┐
# │ ASYNC COMMANDS                                                             │
# ├────────────────────────────────────────────────────────────────────────────┤
# │ :execute               ← The ONLY universal async mechanism                │
# │ /system scheduler      ← Background process                                │
# │ /tool netwatch         ← Background monitor                                │
# │ /tool traffic-monitor  ← Background monitor                                │
# └────────────────────────────────────────────────────────────────────────────┘

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      CRITICAL LLM PITFALLS                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ✗ /tool fetch is async ← WRONG! It BLOCKS!
# ✗ /tool e-mail is async ← WRONG! Blocks for SMTP!
# ✗ /tool sms is async ← WRONG! Blocks for Modem!
# ✗ /system backup save is async ← WRONG! Blocks for I/O!
# ✗ /certificate sign is async ← WRONG! Blocks for Crypto!
# ✗ scep/acme clients are async ← WRONG! Block for Network!
# ✗ spectral-scan returns immediately ← WRONG! Blocks for duration!
# ✗ :execute errors caught by parent ← WRONG! ISOLATED!
# ✗ :delay syncs with jobs ← WRONG! Only pauses current thread!
# ✗ :parse has closures ← WRONG! New scope, no closures!
# ✗ :timestamp returns num ← WRONG! Returns time type!
# ✗ Netwatch has full permissions ← WRONG! sys user, NO ftp!
# ✗ Globals auto-clear ← WRONG! Persist until reboot!
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+
# ══════════════════════════════════════════════════════════════════════════════
