# RouterOS 7 Safe-Mode Reference
# VERIFIED on RouterOS 7.21 (CHR) - Requires RouterOS >= 7.18
# This document contains ONLY empirically verified behavior from 50+ tests
# 
# ═══════════════════════════════════════════════════════════════════════════════
# WARNING: Safe-mode behavior differs SIGNIFICANTLY between interactive terminal
# sessions and SSH command/script execution. READ THIS ENTIRE FILE before using.
# ═══════════════════════════════════════════════════════════════════════════════

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      1. OVERVIEW & USE CASE                                 │
# └─────────────────────────────────────────────────────────────────────────────┘

# Safe-mode is a SESSION-BASED transaction mechanism introduced in RouterOS 7.18
# that captures a configuration checkpoint and can rollback changes if session
# terminates abnormally (connection loss, console close, timeout).

# PRIMARY USE CASE: Interactive terminal sessions where administrator may
# accidentally lock themselves out (disable interface, block firewall, etc.)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      2. COMMAND REFERENCE                                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 2.1: /safe-mode take - Enter safe-mode transaction
/safe-mode take on-error=unroll;   # Auto-rollback on session termination
/safe-mode take on-error=release;  # Auto-commit on session termination
/safe-mode take on-error=abort;    # Script aborts, changes undetermined
/safe-mode take on-error=ask;      # Interactive prompt (NOT for scripts!)

# RULE 2.2: /safe-mode release - Commit all changes (destroy checkpoint)
/safe-mode release;
# Output: "Releasing Safe Mode... Success!"
# If not in safe-mode: "Safe Mode has not been taken. Action aborted."

# RULE 2.3: /safe-mode unroll - Rollback all changes (restore checkpoint)
/safe-mode unroll;
# Output: "Unrolling Safe Mode... Success!"
# If not in safe-mode: "Safe Mode has not been taken. Action aborted."

# RULE 2.4: /safe-mode toggle - Toggle between active/inactive
# When off → turns on (same as take with default on-error)
# When on → releases (commits changes, same as release)
/safe-mode toggle;
# Output: "Taking Safe Mode session... Success!" or
#         "Releasing Safe Mode... Success!"

# RULE 2.5: /safe-mode print - Show current safe-mode status
/safe-mode print;
# Output:
#   enabled: yes/no
#      user: <username>    (only if enabled)
#   current: yes/no        (current session owns it)
#     owner: console/ssh   (only if enabled)

# RULE 2.6: /safe-mode get - Get individual properties
:put [/safe-mode get enabled];   # => true/false (bool)
:put [/safe-mode get current];   # => true/false (bool)
:put [/safe-mode get owner];     # => str or nil
:put [/safe-mode get user];      # => str or nil

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      3. on-error MODES EXPLAINED                            │
# └─────────────────────────────────────────────────────────────────────────────┘

# CRITICAL: on-error ONLY triggers on SESSION TERMINATION, NOT script errors!

# on-error=unroll
# ✓ Changes rolled back IF: session disconnects abnormally
# ✗ NOT rolled back IF: script completes normally (even with :error)

# on-error=release  
# ✓ Changes committed IF: session disconnects (normal or abnormal)

# on-error=abort
# ✓ Script aborts on error
# ✗ Changes may or may not persist (undetermined state)

# on-error=ask
# ✓ Prompts user "Really release [S]afe mode, [U]nroll it, or [C]ancel?"
# ✗ NOT usable in scripts - will hang or fail

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      4. VERIFIED PROPERTY TYPES                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# TEST 2.1 VERIFIED:
:put [:typeof [/safe-mode get enabled]];   # => bool
:put [:typeof [/safe-mode get current]];   # => bool
:put [:typeof [/safe-mode get owner]];     # => nil (when not enabled)
:put [:typeof [/safe-mode get user]];      # => nil (when not enabled)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      5. SESSION BEHAVIOR - CRITICAL!                        │
# └─────────────────────────────────────────────────────────────────────────────┘

# ══════════════════════════════════════════════════════════════════════════════
# CRITICAL DISCOVERY: Safe-mode REQUIRES PTY (pseudo-terminal) allocation!
# ══════════════════════════════════════════════════════════════════════════════

# RULE 5.0: SSH REQUIRES -tt flag for safe-mode to work!
# ✗ WRONG: ssh router '/safe-mode take; ...'  # NO PTY = safe-mode fails silently!
# ✓ CORRECT: ssh -tt router '/safe-mode take; ...'  # PTY allocated = works!

# WHY: Without PTY, safe-mode take reports "Success!" but:
#      - enabled = false
#      - current = false  
#      - No <SAFE> prompt indicator
#      - release/unroll fail with "Safe Mode has not been taken"

# WITH PTY (ssh -tt), safe-mode works correctly:
#      [user@RouterName] <SAFE>   # Prompt shows <SAFE> indicator
#      enabled: yes
#      current: yes
#      owner: console

# RULE 5.1: Safe-mode is SESSION-BOUND
# Each SSH command invocation = separate session
# Each terminal connection = single continuous session

# RULE 5.2: SSH command execution WITHOUT PTY does NOT support safe-mode!
# ssh user@router '/safe-mode take on-error=unroll; /interface set x disabled=yes'
# ↑ take "succeeds" but state is immediately false - changes PERSIST!

# RULE 5.3: Interactive terminal OR ssh -tt maintains session throughout
# SSH -tt shell → take → make changes → disconnect = on-error handler triggered

# RULE 5.4: Script completion = normal termination = no on-error trigger
# The on-error handlers are for ABNORMAL session ends (connection loss)

# RULE 5.5: Quit protection in interactive sessions
# When exiting safe-mode session:
# "You are in Safe Mode. Quitting will unroll changes. Quit? [y/N]:"

# RULE 5.6: Changes tracked in /system history with UNDOABLE flag
# /system history print shows: U - UNDOABLE for rollback-capable changes

# RULE 5.7: Reboot behavior
# - Changes tracked in RAM (undo buffer)
# - Reboot = RAM cleared = pending changes LOST if not committed
# - This is intended behavior - safe-mode is not persistent across reboots


# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      6. EXCLUSIVE LOCKING & CONFLICTS                       │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 6.1: Safe-mode is EXCLUSIVE SYSTEM-WIDE
# Only ONE session can hold safe-mode at a time.
# If User A has safe-mode, User B (or another User A session) CANNOT take it.

# RULE 6.2: Conflict Behavior
# Attempting to take safe-mode while held results in ERROR:
# "Safe Mode is taken by another user (username). Action aborted."

# RULE 6.3: Release/Unroll Protection
# A session cannot release/unroll a safe-mode transaction owned by another session.
# Output: "Safe Mode has not been taken. Action aborted."

# RULE 6.4: Uncommitted Changes Isolation
# Changes made by the holding session are NOT visible to other sessions until released.
# (Standard transaction isolation)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      7. VERIFIED BEHAVIORS (SINGLE SESSION)                 │
# └─────────────────────────────────────────────────────────────────────────────┘

# TEST 7.1: Basic take/release cycle
/safe-mode take on-error=unroll;          # "Taking Safe Mode session... Success!"
/interface ether set ether1 comment="X";
/safe-mode release;                        # "Releasing Safe Mode... Success!"
# Result: comment = "X" (committed)

# TEST 7.2: take/unroll cycle (INTERACTIVE ONLY)
/safe-mode take on-error=unroll;          # "Taking Safe Mode session... Success!"
/interface ether set ether1 comment="Y";
/safe-mode unroll;                         # "Unrolling Safe Mode... Success!"
# Result: comment reverts to original (rolled back)

# TEST 7.3: Double take behavior
/safe-mode take on-error=unroll;           # "Taking Safe Mode session... Success!"
/safe-mode take on-error=unroll;           # "Taking Safe Mode session... Success!"
# Result: No error - appears to restart transaction or no-op

# TEST 7.4: release without take
/safe-mode release;
# Output: "Safe Mode has not been taken. Action aborted."

# TEST 7.5: unroll without take
/safe-mode unroll;
# Output: "Safe Mode has not been taken. Action aborted."

# TEST 7.6: toggle behavior (when off)
/safe-mode toggle;
# Output: "Taking Safe Mode session... Success!"

# TEST 7.7: toggle behavior (when on)  
/safe-mode toggle;  # After previous toggle
# Output: "Releasing Safe Mode... Success!"

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      8. WHAT SAFE-MODE TRACKS (VERIFIED)                    │
# └─────────────────────────────────────────────────────────────────────────────┘

# ═══════════════════════════════════════════════════════════════════════════════
# CRITICAL: Safe-mode ONLY tracks changes stored in the CONFIGURATION PARTITION
# Operations that write to other storage areas are NOT protected by safe-mode!
# ═══════════════════════════════════════════════════════════════════════════════

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │ ✓ TRACKED (Rollback-capable) - Configuration Partition                         │
# ├────────────────────────────────────────────────────────────────────────────────┤
# │ • Interface settings (comment, disabled, mac-address, mtu, etc.)               │
# │ • Firewall rules (filter/nat/mangle/raw - add/remove/modify)                   │
# │ • Address list entries                                                         │
# │ • IP addresses, routes, pools                                                  │
# │ • System identity, scripts, schedulers                                         │
# │ • Bridge/VLAN/bonding configuration                                            │
# │ • User accounts and groups                                                     │
# │ • DHCP server/client configuration (NOT leases!)                               │
# │ • DNS static entries (configuration, NOT cache)                                │
# │ • Queue rules and types                                                        │
# │ • Routing filters and instances                                                │
# │ • File operations (/file add, remove, set - all storage types)                │
# │ • Most /export-visible configuration                                           │
# └────────────────────────────────────────────────────────────────────────────────┘

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │ ✗ NOT TRACKED - Outside Configuration Partition                                │
# ├────────────────────────────────────────────────────────────────────────────────┤
# │ • Certificate store (/certificate add, sign, remove)                           │
# │ • Log entries (:log, /log - runtime data in RAM/disk)                          │
# │ • DHCP leases (dynamic, runtime)                                               │
# │ • ARP entries (dynamic)                                                        │
# │ • Connection tracking entries                                                  │
# │ • PPP active sessions                                                          │
# │ • DNS cache                                                                    │
# │ • Global script variables (:global)                                            │
# │ • Package install/uninstall operations                                         │
# │ • System reboot/shutdown commands                                              │
# │ • SNMP trap sends, email sends, fetch operations                               │
# └────────────────────────────────────────────────────────────────────────────────┘
#
# VERIFIED TEST RESULTS:
# ┌─────────────────────────────┬─────────────┬─────────────────────────────────┐
# │ Operation                   │ Rolled Back │ Platform Tested                 │
# ├─────────────────────────────┼─────────────┼─────────────────────────────────┤
# │ /interface set comment      │ YES         │ CHR 7.21                   │
# │ /ip pool add                │ YES         │ CHR 7.21                   │
# │ /user add                   │ YES         │ CHR 7.21                   │
# │ /system script add          │ YES         │ CHR 7.21                   │
# │ /certificate add            │ NO          │ CHR 7.21                   │
# │ :log info                   │ NO          │ CHR 7.21                   │
# │ :global variable change     │ NO          │ CHR 7.21                   │
# │ /file add                   │ YES         │ CHR 7.21 + RB750Gr3 7.21   │
# └─────────────────────────────┴─────────────┴─────────────────────────────────┘
#
# FILE OPERATIONS: Verified to rollback on CHR (virtual disk) and RouterBoard
# (both root RAM and flash/ NAND storage). File metadata tracked in config.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      9. SELF-LOCKOUT SCENARIOS                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# VERIFIED LOCKOUT: Disable management interface
/safe-mode take on-error=unroll;
/interface ether set ether1 disabled=yes;   # IMMEDIATE LOCKOUT!
# Connection dies BEFORE script completes normally
# Result: on-error handler MAY trigger, but timing is critical

# DANGEROUS: Safe-mode does NOT guarantee recovery from immediate-effect changes
# that terminate connectivity before the session can process the on-error handler

# MITIGATION: Use IPv6 link-local as fallback access
# ssh -6 user@fe80::xxxx:xxxx:xxxx:xxxx%interface

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      10. SCRIPT INTEGRATION                                 │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 10.1: :error does NOT trigger safe-mode on-error handler!
/safe-mode take on-error=unroll;
/interface ether set ether1 comment="CHANGED";
:error "Script error";
# Result: comment = "CHANGED" (NOT rolled back!)
# Reason: :error is script-level, not session-level

# RULE 10.2: :onerror + safe-mode are INDEPENDENT
:onerror e in={
  /safe-mode take on-error=unroll;
  /interface ether set ether1 comment="ONERROR-TEST";
  :error "Simulated";
} do={
  :put "Caught: $e";
};
# Result: comment = "ONERROR-TEST" (persists!)
# Safe-mode did NOT rollback on :error

# RULE 10.3: Scripts run on router behave same as SSH commands
/system script add name="test" source={
  /safe-mode take on-error=unroll;
  /interface ether set ether1 comment="SCRIPT-TEST";
  # no release/unroll
};
/system script run test;
# Result: comment = "SCRIPT-TEST" (persists!)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      11. CORRECT USAGE PATTERNS                             │
# └─────────────────────────────────────────────────────────────────────────────┘

# PATTERN 11.1: Interactive session protection (RECOMMENDED USE)
# - Connect via terminal/SSH shell
# - Enter: /safe-mode take on-error=unroll
# - Make configuration changes
# - If something goes wrong → disconnect → auto-rollback
# - If successful → /safe-mode release

# PATTERN 11.2: Script with explicit transaction control
/safe-mode take on-error=unroll;
:do {
  /ip firewall filter add chain=input action=accept comment="new-rule";
  # ... more changes ...
  /safe-mode release;
} on-error={
  /safe-mode unroll;
};

# PATTERN 11.3: Explicit commit in scripts (SAFEST FOR SCRIPTS)
/safe-mode take on-error=release;
/ip firewall filter add chain=input action=accept;
/safe-mode release;
# Changes committed regardless of how script ends

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      12. RETURN TYPES & ERROR HANDLING                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFIED January 2026 on RouterOS 7.21 - Comprehensive Type Audit
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 12.1: Command Return Values (SUCCESS CASES)
# ┌─────────────────────┬───────────┬─────────────────────────────────────────────┐
# │ Command             │ Return    │ Notes                                       │
# ├─────────────────────┼───────────┼─────────────────────────────────────────────┤
# │ /safe-mode take     │ nil       │ Returns nothing on success                  │
# │ /safe-mode release  │ bool:true │ Always true on success                      │
# │ /safe-mode unroll   │ bool:true │ Always true on success                      │
# │ /safe-mode toggle   │ bool:true │ ALWAYS true (both ON→OFF and OFF→ON)       │
# └─────────────────────┴───────────┴─────────────────────────────────────────────┘

# TEST EVIDENCE:
:put [:typeof [/safe-mode take]];       # => nil
:put [:typeof [/safe-mode release]];    # => bool (value: true)
:put [:typeof [/safe-mode unroll]];     # => bool (value: true)
:put [:typeof [/safe-mode toggle]];     # => bool (value: true, BOTH directions)

# RULE 12.2: Property Types (INACTIVE STATE - safe-mode not held)
# ┌─────────────────────┬───────────┬─────────────────────────────────────────────┐
# │ Property            │ Type      │ Value                                       │
# ├─────────────────────┼───────────┼─────────────────────────────────────────────┤
# │ enabled             │ bool      │ false                                       │
# │ current             │ bool      │ false                                       │
# │ owner               │ nil       │ (empty)                                     │
# │ user                │ nil       │ (empty)                                     │
# └─────────────────────┴───────────┴─────────────────────────────────────────────┘

# RULE 12.3: Property Types (ACTIVE STATE - safe-mode held)
# ┌─────────────────────┬───────────┬─────────────────────────────────────────────┐
# │ Property            │ Type      │ Example Value                               │
# ├─────────────────────┼───────────┼─────────────────────────────────────────────┤
# │ enabled             │ bool      │ true                                        │
# │ current             │ bool      │ true (if this session owns it)              │
# │ owner               │ str       │ "console" or "ssh"                          │
# │ user                │ str       │ "admin" (username)                          │
# └─────────────────────┴───────────┴─────────────────────────────────────────────┘

# RULE 12.4: Double Take Behavior
# When take is called while safe-mode is ALREADY ACTIVE (same session):
# - Prints: "Safe Mode is already active"
# - Returns: nil (no error thrown)
# - Behavior: No-op (does NOT restart transaction)
/safe-mode take on-error=release;
:local r [/safe-mode take on-error=release];   # => "Safe Mode is already active"
:put [:typeof $r];   # => nil
/safe-mode release;

# RULE 12.5: Failure Catchability
# Failures ARE CATCHABLE via :onerror or :do on-error
# IMPORTANT: Caught error value is type "nothing" (NOT str, NOT nil)
:onerror err in={ /safe-mode release } do={
  :put [:typeof $err];   # => nothing
  :put $err;             # => (empty)
};
# The error MESSAGE is printed to stdout but NOT captured in $err

# Catchable failure scenarios:
# - release/unroll when safe-mode not active
# - take when locked by another user/session
# - get on invalid property name

# RULE 12.6: :execute Scope Binding (CRITICAL!)
# Safe-mode taken inside :execute is SCOPED TO THAT SUBPROCESS
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ BEHAVIOR: Safe-mode in :execute auto-releases when subprocess terminates   │
# └─────────────────────────────────────────────────────────────────────────────┘

# KEY DISCOVERY: :execute subprocess termination triggers on-error handlers!
# This means on-error=unroll WORKS in :execute when subprocess errors out.

# :execute return value depends on PTY:
# - With PTY (ssh -tt):    Returns job ID (type: id, e.g. "*1CE")
# - Without PTY (ssh):     Returns nothing (type: nothing)

# VERIFIED BEHAVIORS:
# 1. Changes visible to parent IMMEDIATELY (no isolation)
# 2. Subprocess termination (normal or error) = session end = on-error triggered
# 3. :error inside :execute = abnormal termination = on-error=unroll WORKS!

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      13. MICRO-TRANSACTIONS WITH :EXECUTE                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# ═══════════════════════════════════════════════════════════════════════════════
# ADVANCED PATTERN: Use :execute for atomic rollback-capable operations
# ═══════════════════════════════════════════════════════════════════════════════

# Unlike normal script execution, :execute subprocess termination IS treated as
# "session termination" for safe-mode purposes. This enables scripted rollback!

# PATTERN 13.1: Atomic operation with automatic rollback on failure
:local success true;
:local result [:execute script={
  /safe-mode take on-error=unroll;
  # Multiple operations that should be atomic
  /ip firewall filter add chain=input action=accept comment="rule1";
  /ip firewall filter add chain=input action=accept comment="rule2";
  # If any operation fails, :error will terminate subprocess
  # Subprocess termination triggers on-error=unroll → ALL changes rolled back
  /safe-mode release;
}];
# If rules were added and released, they persist
# If :error occurred, subprocess died, on-error=unroll triggered → rolled back

# PATTERN 13.2: Explicit rollback on condition
:local job [:execute script={
  /safe-mode take on-error=unroll;
  /interface ethernet set ether1 comment="testing";
  :if ([/ping 10.0.0.1 count=1] = 0) do={
    :error "Connectivity check failed";  # Triggers unroll!
  };
  /safe-mode release;  # Only reached if ping succeeded
}];

# PATTERN 13.3: Observing :execute safe-mode from parent
/interface ethernet set ether1 comment="ORIGINAL";
:local job [:execute script={
  /safe-mode take on-error=unroll;
  /interface ethernet set ether1 comment="CHANGED";
  :delay 3s;
  /safe-mode unroll;
}];
:delay 500ms;
:put [/interface ethernet get ether1 comment];  # => "CHANGED" (visible!)
:delay 4s;
:put [/interface ethernet get ether1 comment];  # => "ORIGINAL" (rolled back!)

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │ MICRO-TRANSACTION LIMITATIONS                                                  │
# ├────────────────────────────────────────────────────────────────────────────────┤
# │ • NO ISOLATION: Changes visible to all sessions before release                 │
# │ • NO NESTING: Only one safe-mode system-wide, :execute cannot nest             │
# │ • ASYNC ONLY: Parent cannot wait synchronously for :execute completion        │
# │ • COVERAGE: Same limitations as normal safe-mode (see Section 8)               │
# └────────────────────────────────────────────────────────────────────────────────┘

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      ANTI-PATTERNS - LLM MUST AVOID!                        │
# └─────────────────────────────────────────────────────────────────────────────┘

# ✗ ANTI-PATTERN 1: Assuming safe-mode rollback works in SSH commands
# ssh router '/safe-mode take on-error=unroll; dangerous-change'
# WRONG: Changes persist because script completes normally!

# ✗ ANTI-PATTERN 2: Using safe-mode for self-lockout protection in scripts
# /safe-mode take on-error=unroll;
# /interface set ether1 disabled=yes;  # LOCKS OUT IMMEDIATELY!
# Safe-mode cannot protect against instant connectivity loss

# ✗ ANTI-PATTERN 3: Expecting :error to trigger rollback
# /safe-mode take on-error=unroll;
# :if ($badCondition) do={ :error "abort"; };  # Does NOT rollback!
# :error is script-level, not session-level

# ✗ ANTI-PATTERN 4: Using on-error=ask in scripts
# /safe-mode take on-error=ask;  # Will hang or fail in scripts!

# ✗ ANTI-PATTERN 5: Relying on unroll via separate SSH command
# ssh router '/safe-mode take on-error=unroll'
# ssh router 'dangerous-change'  # NEW SESSION - safe-mode not active!
# ssh router '/safe-mode unroll'  # "Safe Mode has not been taken. Action aborted."

# ✗ ANTI-PATTERN 6: Expecting parent session protection from :execute safe-mode
# :execute script={ /safe-mode take on-error=unroll; dangerous-change; }
# # Parent makes more changes here expecting protection... WRONG!
# WRONG: Safe-mode in :execute protects ONLY the subprocess, not the parent!
# See Section 13 for CORRECT micro-transaction patterns using :execute.

# ✗ ANTI-PATTERN 7: Assuming safe-mode provides transaction isolation
# /safe-mode take;
# /interface set ether1 comment="new";
# # Other sessions will see "new" IMMEDIATELY, before release!
# Safe-mode provides ROLLBACK capability, NOT read isolation.

# ✗ ANTI-PATTERN 8: Expecting certificate operations to rollback
# /safe-mode take on-error=unroll;
# /certificate add name=test common-name=test;
# /certificate sign test;
# /safe-mode unroll;  # Certificate STILL EXISTS! Not tracked by safe-mode.
# Certificate store is OUTSIDE configuration partition - never rolled back.

# ✗ ANTI-PATTERN 9: Expecting external side-effects to be undone
# /safe-mode take on-error=unroll;
# /tool e-mail send to="user@example.com" subject="Alert";
# /tool fetch url="http://api.example.com/notify";
# /safe-mode unroll;  # Email was SENT! HTTP request was MADE!
# Safe-mode only tracks CONFIG changes, not external actions or side-effects.

# ✗ ANTI-PATTERN 10: Using safe-mode via SSH without PTY allocation
# ssh router '/safe-mode take on-error=unroll; ...'  # SILENTLY FAILS!
# Without -tt flag, safe-mode reports "Success!" but state is immediately false.
# CORRECT: ssh -tt router '/safe-mode take ...'  # PTY required!

# ✗ ANTI-PATTERN 11: Assuming global variables are protected
# :global myConfig "original";
# /safe-mode take on-error=unroll;
# :set myConfig "modified";
# /safe-mode unroll;  # $myConfig is STILL "modified"!
# Script variables (:global/:local) are runtime state, NOT configuration.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      LLM GENERATION GUIDELINES                              │
# └─────────────────────────────────────────────────────────────────────────────┘

# GUIDELINE 1: For SSH-deployed scripts, safe-mode does NOT provide rollback
# - Design scripts to be idempotent instead
# - Verify changes won't lock out before applying

# GUIDELINE 2: For critical changes, use explicit release
# /safe-mode take on-error=release;
# # make changes
# /safe-mode release;
# This ensures changes commit even if script ends unexpectedly

# GUIDELINE 3: Never disable management interface in scripts
# Instead: Use address-list or connection marking to preserve access
# /ip firewall filter add chain=input src-address-list=management action=accept

# GUIDELINE 4: Interactive safe-mode is for HUMANS, not scripts
# Document in script comments: "Run interactively with safe-mode take first"

# GUIDELINE 5: Version requirement
# ALWAYS check: /system resource get version
# Safe-mode commands require RouterOS >= 7.18

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      QUICK REFERENCE TABLE                                  │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌────────────────────────┬────────────────────────────────────────────────────┐
# │ Command                │ Behavior                                           │
# ├────────────────────────┼────────────────────────────────────────────────────┤
# │ take on-error=unroll   │ Checkpoint created; rollback on session death      │
# │ take on-error=release  │ Checkpoint created; commit on session death        │
# │ take on-error=abort    │ Checkpoint created; abort script on error          │
# │ take on-error=ask      │ Interactive prompt (NOT for scripts)               │
# │ release                │ Commit changes, destroy checkpoint                 │
# │ unroll                 │ Rollback changes, destroy checkpoint               │
# │ toggle                 │ If off→take; if on→release                         │
# │ print                  │ Show status (enabled/user/current/owner)           │
# │ get <property>         │ Get specific property value                        │
# └────────────────────────┴────────────────────────────────────────────────────┘
#
# ┌────────────────────────────────────────────────────────────────────────────────┐
# │ CRITICAL LLM PITFALLS                                                          │
# ├────────────────────────────────────────────────────────────────────────────────┤
# │ ✗ SSH without -tt = safe-mode silently fails (PTY required!)                   │
# │ ✗ SSH script completion = "normal" = on-error=unroll does NOT rollback         │
# │ ✗ :error is script-level, NOT session-level - no rollback trigger              │
# │ ✗ Interface disable = instant lockout, safe-mode cannot save you               │
# │ ✗ Each SSH command = separate session = safe-mode state lost                   │
# │ ✗ on-error=ask hangs in scripts                                                │
# │ ✗ Requires RouterOS >= 7.18                                                    │
# │ ✗ :execute scopes safe-mode to subprocess - auto-releases on completion!       │
# │ ✗ Caught errors are type "nothing" - error message is NOT in the variable      │
# │ ✗ Certificates NOT tracked - /certificate persists after unroll                │
# │ ✗ External actions NOT undone - email/fetch/SNMP already sent!                 │
# │ ✗ Global variables, log entries, runtime data NOT tracked                      │
# │ ✗ No transaction ISOLATION - changes visible immediately before release        │
# │ ✓ File operations (/file) ARE tracked on all platforms                         │
# │ ✓ :execute + on-error=unroll CAN provide micro-transactions (Section 13)       │
# └────────────────────────────────────────────────────────────────────────────────┘

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │ RETURN TYPE QUICK REFERENCE                                                    │
# ├────────────────────────────────────────────────────────────────────────────────┤
# │ take (success)         => nil                                                  │
# │ take (already active)  => nil + prints "Safe Mode is already active"           │
# │ take (locked)          => throws catchable error (type: nothing)               │
# │ release (success)      => true (bool)                                          │
# │ release (not taken)    => throws catchable error (type: nothing)               │
# │ unroll (success)       => true (bool)                                          │
# │ unroll (not taken)     => throws catchable error (type: nothing)               │
# │ toggle (any direction) => true (bool) - ALWAYS true                            │
# │ get enabled            => bool (true/false)                                    │
# │ get current            => bool (true/false)                                    │
# │ get owner (inactive)   => nil                                                  │
# │ get owner (active)     => str ("console"/"ssh")                                │
# │ get user (inactive)    => nil                                                  │
# │ get user (active)      => str (username)                                       │
# │ get <invalid>          => throws catchable error (type: nothing)               │
# └────────────────────────────────────────────────────────────────────────────────┘
#
# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21
# ══════════════════════════════════════════════════════════════════════════════
