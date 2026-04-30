# RouterOS 7 Safe-Mode Reference
# VERIFIED on RouterOS 7.21+ baseline; 7.18+ additions marked inline
# This document contains ONLY empirically verified behavior from 220+ tests
#
# ═══════════════════════════════════════════════════════════════════════════════
# WARNING: Safe-mode behavior differs SIGNIFICANTLY between interactive terminal
# sessions and SSH command/script execution. READ THIS ENTIRE FILE before using.
#
# 7.18+ SCRIPTABLE SAFE-MODE: 7.18 introduced a script-language `:safe-mode`
# command and a "safe-mode handler" that auto-unrolls on script-end-without-
# release. 7.18 also made safe-mode work in non-PTY SSH context. This SUPERSEDES
# several pre-7.18 assumptions about session-vs-script and PTY requirements.
# Sections 5, 10, 12, 14, 15 are version-gated accordingly.
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
# Returns: bool:true on success; nil if already-active (prints "Safe Mode is already active")

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
# Get all properties at once: returns semicolon-delimited k=v string
:put [/safe-mode get];           # => "current=false;enabled=false;owner=;user="

# RULE 2.7: :safe-mode colon-prefix commands (7.18+) - identical to /safe-mode
# The colon-prefix form is equivalent; both are usable anywhere in scripts.
:safe-mode take on-error=unroll;    # (7.18+) same as /safe-mode take
:safe-mode release;                 # (7.18+) same as /safe-mode release
:safe-mode unroll;                  # (7.18+) same as /safe-mode unroll
:safe-mode toggle;                  # (7.18+) same as /safe-mode toggle
:safe-mode print;                   # (7.18+) same as /safe-mode print
:put [:safe-mode get enabled];      # (7.18+) same as [/safe-mode get enabled]
# NOTE: [:typeof :safe-mode] => "str" — the bare token is a string literal.
# The command form (:safe-mode take ...) is callable; bare :safe-mode is not.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      3. on-error MODES EXPLAINED                            │
# └─────────────────────────────────────────────────────────────────────────────┘

# CRITICAL (7.18+): the on-error= parameter ONLY governs TRUE-disconnect timing
# (network drop, console close). In non-PTY scripted contexts the safe-mode
# HANDLER fires on every script end (clean end, uncaught :error, :exit) and
# AUTO-UNROLLS regardless of on-error=. Only an explicit /safe-mode release
# can commit. See Section 14 for handler semantics.
# REF-AUDIT-SM-ONERROR-RELEASE-NOOP 2026-04-30 7.23rc2.

# on-error=unroll
# ✓ Disconnect mid-session  → handler unrolls (matches parameter)
# ✓ Clean script end         → handler unrolls (parameter agrees)
# ✓ Uncaught :error / :exit  → handler unrolls

# on-error=release
# ✓ Disconnect mid-session  → handler releases (matches parameter)
# ✗ Clean script end         → handler STILL UNROLLS (parameter ignored!)
#   REF-AUDIT-SM-ONERROR-RELEASE-NOOP 2026-04-30 7.23rc2.

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
# 7.18+ CHANGE: Safe-mode NO LONGER requires PTY (non-pseudo-terminal works!)
# ══════════════════════════════════════════════════════════════════════════════

# RULE 5.0: Pre-7.18 vs 7.18+ PTY behavior
# Pre-7.18: SSH without -tt flag caused safe-mode to fail silently:
#   - take reported "Success!" but enabled=false, current=false
#   - release/unroll failed with "Safe Mode has not been taken"
# 7.18+: Non-PTY SSH context FULLY SUPPORTS safe-mode (verified on 7.23rc2):
#   - enabled=true, current=true, owner=console after take
#   - release/unroll work correctly
# IMPORTANT: The safe-mode HANDLER (auto-unroll on script end) fires
#            on all script terminations in 7.18+ — see Section 14.

# RULE 5.1: Safe-mode is SESSION-BOUND
# Each SSH command invocation = separate session
# Each terminal connection = single continuous session

# RULE 5.2: SSH script (ros-deploy / non-PTY) SUPPORTS safe-mode since 7.18+
# Pre-7.18: ssh user@router '/safe-mode take on-error=unroll; ...'
#   ↑ take "succeeded" but state was immediately false - changes PERSISTED!
# 7.18+: Same command works correctly; changes roll back on :error/:exit/normal-end
#   (via handler - see Section 14)

# RULE 5.3: Interactive terminal OR ssh -tt maintains session throughout
# SSH -tt shell → take → make changes → disconnect = on-error handler triggered

# RULE 5.4: Script completion fires the safe-mode HANDLER (7.18+, verified 7.23rc2)
# Pre-7.18 lore claimed "normal completion does not trigger on-error handler"
# — this is REFUTED on 7.18+. Clean script end, uncaught :error, and :exit
# ALL fire the handler and auto-unroll pending changes unless an explicit
# /safe-mode release was already issued. The on-error= parameter only matters
# on TRUE network/session disconnects (no graceful end). See Section 14.
# REF-AUDIT-SM-SCRIPT-END-ROLLS-BACK / REF-AUDIT-SM-ERROR-ROLLS-BACK /
# REF-AUDIT-SM-EXIT-ROLLS-BACK 2026-04-30 7.23rc2.

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

# RULE 6.1: Safe-mode is "exclusive" only against DIFFERENT users (verified 7.23rc2)
# Only one session at a time can hold the "current" flag. Cross-USER second
# `take` is rejected as a catchable error ("Safe Mode is taken by another user
# (username). Action aborted."). HOWEVER, SAME-USER second `take` is NOT a
# mutex — see RULE 6.5. Cross-user behavior NOT empirically re-verified in
# Sprint 7 (only `ni` user available on lab).

# RULE 6.2: Conflict Behavior (cross-user)
# Cross-user attempt to take safe-mode while held by ANOTHER USER raises a
# CATCHABLE error: "Safe Mode is taken by another user (username). Action
# aborted." (See RULE 6.5 for same-user behavior — completely different.)

# RULE 6.3: Release/Unroll Protection
# A session cannot release/unroll a safe-mode transaction owned by another
# session — prints "Safe Mode has not been taken. Action aborted." and is
# NON-CATCHABLE; the script continues past the call. See RULE 12.5.

# RULE 6.4: NO TRANSACTION ISOLATION (verified 7.23rc2 — refutes prior claim)
# Changes made by the holding session ARE visible to other sessions
# IMMEDIATELY, before release. Safe-mode provides ROLLBACK, NOT isolation.
# Concurrent SSH/script sessions can read each other's IN-FLIGHT uncommitted
# config changes mid-transaction. Do NOT assume mutual exclusion of reads.
# REF-AUDIT-SM-NO-ISOLATION-MULTISESSION 2026-04-30 7.23rc2.

# RULE 6.5: SAME-USER SECOND `take` STEALS AND COMMITS PRIOR TX (DANGER)
# (verified 7.23rc2) Same-user second `take` from a different session SUCCEEDS
# (returns bool:true), becomes the new owner, AND COMMITS the prior session's
# pending changes — instead of aborting them. The first session's auto-unroll
# on its own end then only rolls back the SECOND session's transaction. This
# is fundamentally broken mutex semantics. Do NOT rely on safe-mode for
# cross-process atomicity.
# REF-AUDIT-SM-SAME-USER-CONTENTION 2026-04-30 7.23rc2.

# RULE 6.6: owner=console is INVARIANT — useless for session attribution
# Every non-PTY session reports owner=console; the field cannot identify
# WHICH session holds safe-mode. Use /safe-mode print user: row instead, but
# note even that does not disambiguate two sessions of the same user.
# (PTY-side empirical equivalence not confirmed: RouterOS PTY ssh+cmd hangs.)
# See new Section 14a "ISOLATION & MULTI-SESSION REALITY" below.

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

# TEST 7.3: Double take behavior (same session)
/safe-mode take on-error=unroll;           # "Taking Safe Mode session... Success!"
:local r [/safe-mode take on-error=unroll];# prints "Safe Mode is already active"
:put [:typeof $r];                         # => nil (NOT bool, NOT error)
# Result: no-op; ownership unchanged; second-call return is nil (NOT catchable).
# REF-AUDIT-SM-DOUBLE-TAKE-NIL 2026-04-30 7.23rc2.
# Cross-session same-user second take is DIFFERENT — see RULE 6.5.

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
# VERIFIED TEST RESULTS (re-confirmed 7.23rc2 unless noted):
# ┌─────────────────────────────┬─────────┬───────────────────────────────────────┐
# │ Operation                   │ Rolled  │ Anchor                                │
# │                             │ Back    │                                       │
# ├─────────────────────────────┼─────────┼───────────────────────────────────────┤
# │ /interface ether set comment│ YES     │ REF-AUDIT-SM-INTERFACE-COMMENT-TRACKED│
# │ /ip firewall filter add     │ YES     │ REF-AUDIT-SM-FIREWALL-TRACKED         │
# │ /ip firewall address-list   │ YES     │ Sprint 7 (multiple probes)            │
# │ /ip pool add                │ YES     │ CHR 7.21                              │
# │ /user add                   │ YES     │ CHR 7.21                              │
# │ /system script add          │ YES     │ CHR 7.21                              │
# │ /certificate add            │ NO      │ REF-AUDIT-SM-CERT-NOT-TRACKED         │
# │ :log info                   │ NO      │ REF-AUDIT-SM-LOG-NOT-TRACKED          │
# │ :global variable change     │ NO      │ REF-AUDIT-SM-GLOBAL-NOT-TRACKED       │
# │ /file add                   │ YES     │ CHR 7.21 + RB750Gr3 7.21              │
# └─────────────────────────────┴─────────┴───────────────────────────────────────┘
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

# RULE 10.1: Handler trigger conditions (7.18+, verified 7.23rc2)
# The safe-mode HANDLER fires (auto-unrolls pending changes) on:
#   - Clean script end without explicit /safe-mode release
#       REF-AUDIT-SM-SCRIPT-END-ROLLS-BACK 2026-04-30 7.23rc2.
#   - Uncaught :error reaching the top of the session
#       REF-AUDIT-SM-ERROR-ROLLS-BACK 2026-04-30 7.23rc2.
#   - :exit terminating the script
#       REF-AUDIT-SM-EXIT-ROLLS-BACK 2026-04-30 7.23rc2.
# The handler does NOT fire when :error is CAUGHT by :onerror/:do — the
# session, in-flight changes, and ownership all persist past the catch.
#   REF-AUDIT-SM-ERROR-CAUGHT-PERSIST 2026-04-30 7.23rc2.
/safe-mode take on-error=unroll;
/interface ether set ether1 comment="CHANGED";
:error "Script error";
# 7.18+: comment reverts to original (handler fires on uncaught :error)
# NOTE: on-error= value does NOT affect handler behavior for non-PTY scripts.
#       Clean end, uncaught :error, :exit all trigger UNROLL regardless.

# RULE 10.2: Caught :error does NOT trigger handler (verified 7.23rc2)
:onerror e in={
  /safe-mode take on-error=unroll;
  /interface ether set ether1 comment="ONERROR-TEST";
  :error "Simulated";
} do={
  :put "Caught: $e";
};
# Result: changes PERSIST during the catch block; safe-mode session stays
# enabled=true / current=true. Explicit /safe-mode unroll inside do={} is
# REQUIRED if a partial-state abort is desired. After do={} returns and the
# script ends without release, the OUTER script-end handler then unrolls.
# REF-AUDIT-SM-ERROR-CAUGHT-PERSIST 2026-04-30 7.23rc2.

# RULE 10.3: /system script run shares the CALLING session (verified 7.23rc2)
# /system script run does NOT spawn a separate session/transaction. Safe-mode
# taken inside the script is INHERITED by the calling session and persists
# after `/system script run` returns. The handler does NOT fire on inner
# script end — it only fires when the OUTER session terminates.
# Conversely: outer's auto-unroll silently rolls back inner script's
# "successful" changes, even if the inner script ran to completion.
# REF-AUDIT-SM-COUPLING-ROLLBACK-SCOPE / REF-AUDIT-SM-SCRIPT-RUN-INHERITS
# 2026-04-30 7.23rc2.
/system script add name="test" source={
  /safe-mode take on-error=unroll;
  /interface ether set ether1 comment="SCRIPT-TEST";
  # no release/unroll inside the inner script
};
/system script run test;
:put [/safe-mode get enabled];   # => true (still active in caller!)
:put [/interface ether get ether1 comment];  # => "SCRIPT-TEST" (visible)
# When the OUTER caller ends without release, the handler will then unroll.
# Practical implication: an inner script that takes safe-mode without
# releasing leaks the transaction up to the caller. Always release inside
# the inner script, OR rely on the caller's session-end handler.

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
# CORRECT: Explicit /safe-mode release commits before script end.
# WARNING (7.18+): on-error=release does NOT mean "auto-commit on script end".
# In non-PTY scripted contexts, clean script end auto-UNROLLS regardless of
# on-error= value. Only the explicit /safe-mode release above commits.
# REF-AUDIT-SM-ONERROR-RELEASE-NOOP 2026-04-30 7.23rc2.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      12. RETURN TYPES & ERROR HANDLING                      │
# └─────────────────────────────────────────────────────────────────────────────┘

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFIED January 2026 on RouterOS 7.21 - Comprehensive Type Audit
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 12.1: Command Return Values (SUCCESS CASES) - verified 7.23rc2
# ┌─────────────────────┬───────────┬─────────────────────────────────────────────┐
# │ Command             │ Return    │ Notes                                       │
# ├─────────────────────┼───────────┼─────────────────────────────────────────────┤
# │ /safe-mode take     │ bool:true │ Returns true on successful new take         │
# │ /safe-mode release  │ bool:true │ Always true on success                      │
# │ /safe-mode unroll   │ bool:true │ Always true on success                      │
# │ /safe-mode toggle   │ bool:true │ ALWAYS true (both ON→OFF and OFF→ON)       │
# └─────────────────────┴───────────┴─────────────────────────────────────────────┘
# NOTE: Earlier 7.21 testing found take→nil; 7.23rc2 shows bool:true. Version
#       when this changed is unconfirmed — treat as 7.18+ (scriptable safe-mode).
#       Already-active take returns nil (prints "Safe Mode is already active");
#       see RULE 12.4. Cross-link: REF-AUDIT-SM-TAKE-RETURN /
#       REF-AUDIT-SM-DOUBLE-TAKE-NIL 2026-04-30 7.23rc2.

# TEST EVIDENCE:
:put [:typeof [/safe-mode take]];       # => bool (value: true)
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

# RULE 12.4: Double Take Behavior (SAME SESSION)
# When take is called while safe-mode is ALREADY ACTIVE in the SAME session:
# - Prints: "Safe Mode is already active"
# - Returns: nil (no error thrown, no new take issued)
# - Behavior: No-op (does NOT restart transaction, ownership unchanged)
# REF-AUDIT-SM-DOUBLE-TAKE-NIL 2026-04-30 7.23rc2.
/safe-mode take on-error=release;
:local r [/safe-mode take on-error=release];   # => "Safe Mode is already active"
:put [:typeof $r];   # => nil
/safe-mode release;
# NOTE: Different from initial take (bool:true, REF-AUDIT-SM-TAKE-RETURN).
# CRITICAL contrast: SAME-USER second take from a DIFFERENT session is NOT
# a no-op — it SUCCEEDS, steals ownership, AND commits the prior session's
# pending changes. See RULE 6.5 / REF-AUDIT-SM-SAME-USER-CONTENTION.

# RULE 12.5: Failure Catchability — CRITICAL nuance (verified 7.23rc2)
# Not all "failures" are catchable. Two distinct categories:
#
# (a) NON-CATCHABLE (prints message, script continues past the call):
#     - /safe-mode release  when safe-mode is NOT active
#     - /safe-mode unroll   when safe-mode is NOT active
#     - :safe-mode release / :safe-mode unroll  (same as slash-form)
#     - /safe-mode take     when same session already holds it (returns nil)
#     Each prints "Safe Mode has not been taken. Action aborted." (or
#     "Safe Mode is already active") to stdout — :onerror does NOT trigger,
#     statement after the call EXECUTES NORMALLY.
#     REF-AUDIT-SM-RELEASE-INACTIVE-NONCATCH 2026-04-30 7.23rc2.
#
# (b) CATCHABLE via :onerror / :do on-error (raises real error):
#     - /safe-mode get <invalid-property>     (raises catchable error)
#     - /safe-mode take on-error="bogus"      (raises catchable error)
#     - /safe-mode take when locked by ANOTHER user  (catchable)
#
# Examples:
:onerror err1 in={
  /safe-mode release;       # not active
  :put "I-STILL-RUN";        # this IS reached
} do={ :put "never-runs" };
# Output: "Safe Mode has not been taken. Action aborted." then "I-STILL-RUN"

:onerror err2 in={
  :put [/safe-mode get badprop];
} do={
  :put [:typeof $err2];     # => str (the message)
  :put $err2;
};
# Output: "input does not match any value of value-name (...)"

# RULE 12.6: :execute INHERITS the caller's safe-mode transaction (verified 7.23rc2)
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ BEHAVIOR: :execute runs in the SAME safe-mode transaction as its caller    │
# │ Async additions are rolled back when the OUTER session auto-unrolls        │
# └─────────────────────────────────────────────────────────────────────────────┘
# REF-AUDIT-SM-EXEC-MICROTX 2026-04-30 7.23rc2.

# :execute return value depends on PTY:
# - With PTY (ssh -tt):    Returns job ID (type: id, e.g. "*1CE")
# - Without PTY (ssh):     Returns nothing (type: nothing)

# VERIFIED BEHAVIORS (7.23rc2):
# 1. Changes are visible to parent IMMEDIATELY (no isolation — shared TX)
# 2. :execute add inside an outer safe-mode session is rolled back when the
#    OUTER session auto-unrolls (e.g. clean script end without release)
# 3. The PTY-style "subprocess auto-release on termination" framing is
#    superseded — non-PTY scripted contexts share the outer transaction

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      13. MICRO-TRANSACTIONS WITH :EXECUTE                   │
# └─────────────────────────────────────────────────────────────────────────────┘

# ═══════════════════════════════════════════════════════════════════════════════
# CAVEAT (7.23rc2): :execute DOES NOT create a separate safe-mode transaction.
# It RUNS inside the caller's safe-mode session. Patterns below are useful for
# observing intermediate state, but the outer session's handler is what
# actually performs rollback when the OUTER script ends without release.
# REF-AUDIT-SM-EXEC-MICROTX 2026-04-30 7.23rc2.
# ═══════════════════════════════════════════════════════════════════════════════

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

# ✗ ANTI-PATTERN 1: PRE-7.18 only — no longer applies on 7.18+
# Pre-7.18: ssh router '/safe-mode take on-error=unroll; dangerous-change'
#   → take "succeeded" but state was immediately false; changes PERSISTED.
# 7.18+: same SSH command WORKS — handler unrolls on script end. The actual
# 7.18+ trap is the OPPOSITE: changes auto-UNROLL on script end unless
# /safe-mode release is called explicitly. See PATTERN 11.3 / RULE 14.x.

# ✗ ANTI-PATTERN 2: Using safe-mode for self-lockout protection in scripts
# /safe-mode take on-error=unroll;
# /interface set ether1 disabled=yes;  # LOCKS OUT IMMEDIATELY!
# Safe-mode cannot protect against instant connectivity loss

# ✗ ANTI-PATTERN 3: PRE-7.18 only — :error DOES rollback on 7.18+
# Pre-7.18: :error did NOT trigger handler.
# 7.18+: UNCAUGHT :error fires handler → auto-unroll
#   (REF-AUDIT-SM-ERROR-ROLLS-BACK).
# CAVEAT: :error CAUGHT by :onerror/:do does NOT trigger handler — partial
# state persists past the catch. REF-AUDIT-SM-ERROR-CAUGHT-PERSIST. If
# rollback is desired inside a catch, call /safe-mode unroll explicitly.

# ✗ ANTI-PATTERN 4: Using on-error=ask in scripts
# /safe-mode take on-error=ask;  # Will hang or fail in scripts!

# ✗ ANTI-PATTERN 5: Relying on unroll via separate SSH command
# ssh router '/safe-mode take on-error=unroll'
# ssh router 'dangerous-change'  # NEW SESSION - safe-mode not active!
# ssh router '/safe-mode unroll'  # "Safe Mode has not been taken. Action aborted."

# ✗ ANTI-PATTERN 6: Confusing :execute scope on 7.18+
# :execute does NOT have a private safe-mode transaction. It RUNS inside the
# caller's safe-mode session — changes are visible immediately to all
# sessions, and rollback is governed by the OUTER session's end. Treat
# :execute as a vehicle for async work within the same transaction, NOT as
# a sandbox. REF-AUDIT-SM-EXEC-MICROTX.

# ✗ ANTI-PATTERN 7: Assuming safe-mode provides transaction isolation
# /safe-mode take;
# /interface set ether1 comment="new";
# # Other sessions see "new" IMMEDIATELY, mid-transaction, before release!
# Safe-mode provides ROLLBACK capability, NOT read isolation.
# Concurrent same-user `take` even STEALS ownership and commits prior
# pending changes — see RULE 6.5.
# REF-AUDIT-SM-NO-ISOLATION-MULTISESSION /
# REF-AUDIT-SM-SAME-USER-CONTENTION 2026-04-30 7.23rc2.

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

# ✗ ANTI-PATTERN 10: PRE-7.18 ONLY — non-PTY safe-mode now WORKS
# Pre-7.18: ssh router '/safe-mode take on-error=unroll; ...' silently failed
# (state was immediately false). 7.18+ FULLY supports non-PTY safe-mode:
# enabled=true, current=true, owner=console, take/release/unroll all work.
# The current trap is the OPPOSITE: explicit /safe-mode release REQUIRED;
# clean script end auto-UNROLLS. See PATTERN 11.3.

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
# │ ✗ Pre-7.18 SSH without -tt = safe-mode silently fails (PTY required!)          │
# │ ✓ 7.18+: SSH without -tt WORKS for safe-mode (non-PTY fully supported)         │
# │ ✗ 7.18+: Script end/exit/error triggers handler = AUTO-UNROLL (see §14)        │
# │ ✗ Pre-7.18: :error is script-level, NOT session-level - no rollback trigger    │
# │ ✓ 7.18+: :error terminates script, handler fires, unrolls if on-error=unroll  │
# │ ✗ Interface disable = instant lockout, safe-mode cannot save you               │
# │ ✗ Each SSH command = separate session; only explicit release commits           │
# │ ✗ on-error=ask hangs in scripts                                                │
# │ ✗ Requires RouterOS >= 7.18                                                    │
# │ ✗ :execute SHARES caller's safe-mode TX (NOT a sandbox); rolls back on outer   │
# │ ✗ release/unroll on inactive = NOT catchable; prints "Safe Mode has not        │
# │   been taken" but :onerror does NOT trigger — script just continues            │
# │ ✓ Catchable errors carry message as type "str" in the captured variable        │
# │ ✗ Certificates NOT tracked - /certificate persists after unroll                │
# │ ✗ External actions NOT undone - email/fetch/SNMP already sent!                 │
# │ ✗ Global variables, log entries, runtime data NOT tracked                      │
# │ ✗ No isolation — concurrent sessions see in-flight changes immediately         │
# │ ✗ Same-user 2nd take STEALS ownership AND COMMITS prior pending changes        │
# │ ✗ /system script run inherits caller's TX; outer auto-unroll wipes inner work  │
# │ ✗ Caught :error does NOT trigger handler — partial state persists              │
# │ ✗ take() returns bool:true (was nil pre-7.18); double-take returns nil          │
# │ ✓ File operations (/file) ARE tracked on all platforms                         │
# │ ✗ :execute "micro-transactions" share outer TX — NOT independent rollback      │
# │ ✓ 7.18+: :safe-mode (colon prefix) equivalent to /safe-mode in scripts         │
# └────────────────────────────────────────────────────────────────────────────────┘

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │ RETURN TYPE QUICK REFERENCE (verified 7.23rc2)                                 │
# ├────────────────────────────────────────────────────────────────────────────────┤
# │ take (success)         => true (bool) — changed; was nil pre-7.18              │
# │ take (already active)  => nil + prints "Safe Mode is already active"           │
# │                           NOT catchable; next statement executes normally      │
# │ take (locked-by-other) => CATCHABLE error (type: str)                          │
# │ take on-error=<bogus>  => CATCHABLE error (type: str)                          │
# │ release (success)      => true (bool)                                          │
# │ release (not taken)    => prints "Safe Mode has not been taken. Action         │
# │                           aborted." — NOT CATCHABLE; script continues          │
# │ unroll (success)       => true (bool)                                          │
# │ unroll (not taken)     => prints "Safe Mode has not been taken. Action         │
# │                           aborted." — NOT CATCHABLE; script continues          │
# │ toggle (any direction) => true (bool) - ALWAYS true                            │
# │ get enabled            => bool (true/false)                                    │
# │ get current            => bool (true/false)                                    │
# │ get owner (inactive)   => nil                                                  │
# │ get owner (active)     => str ("console"/"ssh")                                │
# │ get user (inactive)    => nil                                                  │
# │ get user (active)      => str (username)                                       │
# │ get (all, no arg)      => str semicolon-delimited "k=v;k=v" pairs              │
# │ get <invalid>          => CATCHABLE error (type: str = the message)            │
# └────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │              14. SAFE-MODE HANDLER - SCRIPT TERMINATION (7.18+)             │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 14.1: Auto-unroll on script termination (7.18+) - the "safe-mode handler"
# When a script or session ends WITHOUT an explicit /safe-mode release or unroll,
# the 7.18 "safe-mode handler" fires automatically:
# - Default behavior: UNROLL (rollback all pending changes)
# - Applies to: normal script end, :error, :exit, session disconnect
# - The on-error= parameter does NOT change handler behavior for non-PTY scripts

# RULE 14.2: Trigger conditions for the handler
# TRIGGERS handler (auto-unroll):
#   - Script completes normally (reaches end of file) without explicit release
#   - :error aborts the script
#   - :exit terminates the script
# Does NOT trigger handler mid-script:
#   - :error caught by :onerror/:do (script continues)

# RULE 14.3: Explicit release remains the ONLY way to commit
/safe-mode take on-error=unroll;
/ip firewall address-list add list="example" address="10.0.0.1";
/safe-mode release;   # ← EXPLICIT: commits changes
# Without this line, changes would be AUTO-UNROLLED on script end

# RULE 14.4: Handler verification test (confirmed on 7.23rc2)
/safe-mode take on-error=unroll;
/ip firewall address-list add list="T6TEST" address="192.168.100.1";
# No release - script ends here
# Result after script: T6TEST entry does NOT exist (auto-unrolled)
# /safe-mode print: enabled=no, current=no (handler cleaned up state)

# RULE 14.5: on-error= is for TRUE session disconnection only
# on-error=unroll → rollback on network/session drop (still true)
# on-error=release → commit on network/session drop (still true)
# These do NOT apply to normal script completion in non-PTY SSH context
# (handler overrides: always unrolls unless explicit release is called)

# RULE 14.6: :safe-mode inside functions (7.18+)
:local fn do={
  :safe-mode take on-error=unroll;
  # ... make changes ...
  :safe-mode release;     # works from within function
};
[$fn];
# Functions can take and release; handler fires when the OUTER script ends
# without an explicit release. Function-end alone does NOT fire the handler;
# safe-mode is bound to the SESSION, not the function frame.

# RULE 14.7: Handler scope = SESSION, not script invocation (verified 7.23rc2)
# The "script" boundary the handler watches is the IMPORT/SSH session boundary.
# /system script run, [$fn], :do {} blocks all execute in the SAME session and
# do NOT trigger the handler on their own end. Only one of:
#   - the import/SSH session ends, OR
#   - :error/:exit reaches the top of the session (uncaught), OR
#   - the underlying TCP/console connection is dropped
# will fire the handler.

# RULE 14.8: on-error= parameter has NO effect on the auto-unroll handler
# In non-PTY scripted contexts, ALL terminations (normal end, :error, :exit)
# auto-unroll regardless of on-error=unroll/release/abort. The on-error= value
# only takes effect on TRUE session disconnection (network drop, console
# closed) where there is no graceful end-of-script — verified empirically:
#   /safe-mode take on-error=release;
#   /interface ether set ether1 comment="X";
#   # script ends cleanly
#   # → comment is unrolled (NOT released, despite on-error=release)
# This means: in scripted contexts, only an explicit /safe-mode release
# can commit. on-error=release is functionally a no-op for ros-deploy/import.
# REF-AUDIT-SM-ONERROR-RELEASE-NOOP 2026-04-30 7.23rc2.

# RULE 14.9: Handler persists across :execute + :delay (verified 7.23rc2)
# Safe-mode does NOT have an idle timeout. A session may hold safe-mode
# across long :execute jobs and :delay calls without auto-release. Verified:
# take + :execute (5s) + :delay 7s → still enabled=true, current=true; manual
# release commits cleanly.
# REF-AUDIT-SM-TIMEOUT-INTERACTION 2026-04-30 7.23rc2.

# RULE 14.10: Rapid take/release cycle is leak-free (verified 7.23rc2)
# 100 sequential :do { /safe-mode take; /safe-mode release } iterations
# completed with zero errors and final enabled=false / current=false. No
# resource leak observed.
# REF-AUDIT-SM-RAPID-TAKE-RELEASE-CYCLE 2026-04-30 7.23rc2.

# RULE 14.11: PTY vs non-PTY equivalence — partially verified
# Non-PTY (ros-deploy / ssh user@router 'cmd'): safe-mode FULLY supported on
# 7.18+; owner field reads "console". PTY-side equivalence NOT confirmable —
# RouterOS rejects PTY ssh + command argument (interactive shell hangs or
# aborts on input). Treat owner=console as the only empirically-confirmed
# value for scripted execution. Use the user: row of /safe-mode print for
# user-level attribution; owner is uninformative.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │       14a. ISOLATION & MULTI-SESSION REALITY (verified 7.23rc2)             │
# └─────────────────────────────────────────────────────────────────────────────┘

# CRITICAL: Safe-mode does NOT provide cross-session isolation. Multiple SSH
# or scripted sessions share global safe-mode state. The implications below
# are surprising and broken-by-design — treat safe-mode as a SINGLE-SESSION
# rollback aid, never as a multi-process coordination primitive.

# RULE 14a.1: No mid-transaction read isolation
# Concurrent session B (no take) sees session A's IN-FLIGHT uncommitted
# config additions, deletions, and modifications. The "enabled" flag is
# global; only the "current" flag is per-session.
# REF-AUDIT-SM-NO-ISOLATION-MULTISESSION 2026-04-30 7.23rc2.

# RULE 14a.2: Same-user contention SUCCEEDS and COMMITS prior pending changes
# When session A holds safe-mode and same-user session B calls /safe-mode
# take, B's take SUCCEEDS (returns bool:true). B becomes the new owner. A's
# pending changes are NOT discarded — they are COMMITTED into the
# configuration. B then begins a fresh transaction; B's auto-unroll on
# script-end rolls back B's transaction only. This is fundamentally broken
# mutex semantics: do NOT rely on safe-mode for cross-process atomicity.
# REF-AUDIT-SM-SAME-USER-CONTENTION 2026-04-30 7.23rc2.

# RULE 14a.3: owner=console invariant (no per-session attribution)
# Every non-PTY scripted session reports owner=console. The field is
# useless for "which session has it". Use /safe-mode print's user: row
# as a coarse attribution; do NOT assume owner discriminates between two
# sessions of the same user (it does not).

# RULE 14a.4: Cross-USER second `take` — DEFERRED (lab limitation)
# Sprint 7 only had user `ni` available on the CHR; cross-user contention
# semantics (whether B-as-other-user can take while A-as-ni holds) NOT
# empirically determined. Cross-user `take` raising a CATCHABLE error is
# documented historical behavior — see RULE 6.2 — but not re-verified on
# 7.23rc2 with this audit.

# RULE 14a.5: External orchestration is the ONLY reliable mutex
# If two deployment scripts must not interfere, serialize them at the
# orchestration layer (file lock, scheduler queue, single-deployer script).
# Do NOT assume safe-mode protects against concurrent operators.

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │              15. /IMPORT TOOLING - DRY-RUN AND VERBOSE (7.16+)              │
# └─────────────────────────────────────────────────────────────────────────────┘

# RULE 15.1: /import verbose modes (7.16+)
# verbose=no (default): executes silently, shows only :put output
# verbose=yes:          shows "#line N" prefix + each command, then output
# verbose=progress:     shows output only (no #line prefix), same as silent but
#                       with identical line-prefix output in error cases
/import file-name="config.rsc";                  # silent (default)
/import file-name="config.rsc" verbose=yes;      # (7.16+) shows each line
/import file-name="config.rsc" verbose=progress; # (7.16+) output-only mode

# RULE 15.2: dry-run parameter (7.16+) - syntax-only check without side effects
# - dry-run REQUIRES verbose=yes or verbose=progress (verbose mode only)
# - Reports ALL syntax errors, not just the first
# - Does NOT execute any commands — zero side effects
# - Does NOT catch runtime errors (bad interface names, duplicate entries, etc.)
# - Summary line: "No syntax errors found in the import file" or
#                 "Script Error: found N error(s) in import file"
/import file-name="config.rsc" verbose=yes dry-run;      # (7.16+)
/import file-name="config.rsc" verbose=progress dry-run; # (7.16+)
# ✗ /import file-name="x.rsc" dry-run  → "dry-run parameter cannot be used
#                                          in non-verbose mode"

# RULE 15.3: dry-run is a bare flag (no =yes), and is CLI-and-script usable
# ✗ WRONG:  /import file-name="x.rsc" dry-run=yes  → parse error in scripts
# ✓ CORRECT: /import file-name="x.rsc" verbose=yes dry-run  → works
# ✗ WRONG:  /import file-name="x.rsc" verbose=yes dry-run dry-run
#           → "bad parameter dry-run" (it's a single flag, not stackable)

# RULE 15.3a: dry-run is SYNTAX-ONLY (verified 7.23rc2)
# dry-run does NOT execute commands at all — so RUNTIME errors are NOT
# caught. Examples: bad interface name, missing IP address, schema-violating
# argument values are SILENT under dry-run because the command never runs.
# Only PARSE-time errors (bad command name, syntax error, bad parameter)
# are reported. Cross-field semantic validation (e.g. "this firewall rule
# references a nonexistent address-list") is not checked.
# Side-effect proof: a dry-run of a script that sets a /interface comment
# leaves the comment unchanged; a normal verbose=yes run applies it.

# RULE 15.4: from-line parameter (7.16+) — verified 7.23rc2
# Skips lines 1..N-1, starts execution from line N.
# - from-line=0  : starts from first line (treated as 1)
# - from-line=N  : valid range 0..4294967295
# - from-line=-1 : raises CATCHABLE error "value of from-line out of range
#                   (0..4294967295)"
# - from-line past EOF : silent no-op (no error, no output)
# - Requires verbose mode; when used without verbose RouterOS warns
#   "Warning: from-line parameter does not work for non-verbose import"
#   but still proceeds with normal (non-skipped) import.
/import file-name="config.rsc" verbose=yes from-line=5;  # (7.16+) start at line 5
# Output: "#line 1..4, skip" then executes from line 5

# RULE 15.5: import error catchability (7.16+)
# /import errors (syntax and runtime) ARE catchable via :onerror and :do on-error
:onerror e in={
  /import file-name="config.rsc" verbose=yes;
} do={
  :put ("import failed: " . $e);   # e contains error description
};
# dry-run errors also caught: e = "Script Error: found N error(s) in import file"

# RULE 15.6: verbose=yes vs verbose=progress comparison (verified 7.23rc2)
# verbose=yes:       #line 1\n<command>\n<output>    (each line announced)
# verbose=progress:  <output only>                   (progress = just output)
# verbose=progress + ERROR: prints "#line N\n<offending-line>\n<error>"
#                    (progress mode reverts to verbose-style only on error)
# Both modes:        apply changes (no dry-run); stop at FIRST error during run
# Both + dry-run:    show ALL errors; apply NOTHING

# RULE 15.7: :global is partially available in /import context (verified 7.23rc2)
# /import RUNS commands in scripting context: bare `:global name` (declaration
# only, no value) IS accepted. `:set` does work. However certain console-only
# vs script-only nuances apply per command. Side-effect tests confirm that
# `:global x` followed by `:set x "value"` inside an imported file DOES
# produce a runtime-visible global if executed normally.
# IMPORTANT: variable identifiers cannot contain underscores in any RouterOS
# script context (import or otherwise) — `:global T6_VAR` raises
# "expected end of command" at the underscore. Use camelCase: `t6Var`.

# RULE 15.8: dry-run zero-side-effect proof (verified 7.23rc2)
# A file containing `/interface ethernet set ether1 comment="X"` was tested:
#   - /import file-name=... verbose=yes dry-run  → comment unchanged
#   - /import file-name=... verbose=yes          → comment becomes "X"
# Conclusion: dry-run is SAFE to use for syntax validation of unknown files.
# REF-AUDIT-SM-DRY-RUN-NO-EFFECT 2026-04-30 7.23rc2.
# Bare-flag form (no =yes) confirmed in REF-AUDIT-DRYRUN-VERIFY (separate sprint).
# A safe-mode `take` inside a dry-run file is a NO-OP — dry-run does not
# execute any commands at all (the take line is parsed but not invoked).

# RULE 15.9: from-line= silently DISABLED without verbose= (7.23rc2 finding)
# When /import is invoked with from-line=N but WITHOUT verbose=yes (or
# verbose=progress), RouterOS emits a non-fatal warning:
#   "Warning: from-line parameter does not work for non-verbose import"
# AND silently runs the import from line 1, ignoring from-line entirely. The
# warning is easy to miss in non-interactive deploys; LLM-generated scripts
# that rely on partial-line resume must ALWAYS pair from-line= with
# verbose=yes or verbose=progress.
# REF-AUDIT-SM-IMPORT-FROMLINE-PAST-EOF 2026-04-30 7.23rc2.
# See anti-pattern #107.

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │ /IMPORT PARAMETER QUICK REFERENCE (7.16+)                                      │
# ├────────────────────────────────────────────────────────────────────────────────┤
# │ file-name=<x>     Required. Name of .rsc file on router filesystem             │
# │ verbose=no        Default. Silent execution, :put output only                  │
# │ verbose=yes       Show #line N + command + output. Stops at first error        │
# │ verbose=progress  Show output only (same runtime behavior as verbose=yes)      │
# │ dry-run           Verbose-only flag. Check syntax only, NO side effects        │
# │ from-line=N       Verbose-only. Skip lines 1..N-1, start from line N          │
# └────────────────────────────────────────────────────────────────────────────────┘

# ══════════════════════════════════════════════════════════════════════════════
# END OF VERIFIED REFERENCE - RouterOS 7.21+ baseline; 7.18+ additions inline
# ══════════════════════════════════════════════════════════════════════════════
