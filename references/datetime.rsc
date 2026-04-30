# ┌─────────────────────────────────────────────────────────────────────────────┐
# │              RouterOS 7 DateTime Reference (Verified 7.21+)                 │
# │                    Empirically Tested - 500+ Tests                          │
# └─────────────────────────────────────────────────────────────────────────────┘
# Version: 1.1 | Target: RouterOS 7.10+ | Last Verified: 2026-04-30 on 7.23rc2

# ═══════════════════════════════════════════════════════════════════════════════
#                           DATETIME TYPE SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

# ┌────────────────────────┬──────────┬───────────────────────────────────────────┐
# │ Construct              │ Type     │ Format / Example                          │
# ├────────────────────────┼──────────┼───────────────────────────────────────────┤
# │ /system clock get date │ str      │ YYYY-MM-DD (v7.10+)                       │
# │ /system clock get time │ time     │ HH:MM:SS                                  │
# │ :timestamp             │ time     │ 2920w5d07:03:45.210877008                 │
# │ :tonsec                │ num      │ NANOSECONDS (1s = 1,000,000,000)          │
# │ :totime                │ time     │ time type from string                     │
# │ uptime                 │ time     │ 1d02:30:45 (directly comparable)          │
# │ gmt-offset             │ num      │ seconds offset (0 = UTC)                  │
# │ scheduler start-date   │ str      │ YYYY-MM-DD (v7.10+)                       │
# │ scheduler start-time   │ str      │ HH:MM:SS (string!)                        │
# │ script last-started    │ str      │ YYYY-MM-DD HH:MM:SS                       │
# │ file last-modified     │ str      │ YYYY-MM-DD HH:MM:SS                       │
# │ address-list timeout   │ time     │ 6d23:59:59 (max ~35w)                     │
# │ cert expires-after     │ time     │ 6w2d03:04:05 (duration remaining)         │
# │ cert invalid-after     │ str      │ 2025-12-25 12:00:00 (ISO Format)          │
# │ NTP status             │ str      │ "synchronized" / "stopped"                │
# └────────────────────────┴──────────┴───────────────────────────────────────────┘

# ═══════════════════════════════════════════════════════════════════════════════
#                        1. SYSTEM CLOCK - DATE
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 1.1: v7.10+ date format is YYYY-MM-DD (ISO 8601)
:local d [/system clock get date];
:put [:typeof $d];                       # => str
:put $d;                                 # => 2025-12-23

# RULE 1.2: Detect format version
:local isV710Plus ([:pick $d 4 5] = "-");
:put ("ISO format: " . $isV710Plus);     # => true for v7.10+

# RULE 1.3: Parse v7.10+ date
:if ([:pick $d 4 5] = "-") do={
  :local year [:pick $d 0 4];            # => 2025
  :local month [:pick $d 5 7];           # => 12
  :local day [:pick $d 8 10];            # => 23
};

# RULE 1.4: Month name mapping (for old format compatibility)
:global months {"jan"=1;"feb"=2;"mar"=3;"apr"=4;"may"=5;"jun"=6;
                "jul"=7;"aug"=8;"sep"=9;"oct"=10;"nov"=11;"dec"=12};

# ═══════════════════════════════════════════════════════════════════════════════
#                        2. SYSTEM CLOCK - TIME
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 2.1: Time is actual time type
:local t [/system clock get time];
:put [:typeof $t];                       # => time

# RULE 2.2: Time supports comparison operators
:put (12:00:00 > 11:00:00);              # => true
:put (12:00:00 = 12:00:00);              # => true
:put (00:00:00 < 23:00:00);              # => true

# RULE 2.3: Parse time components
:local ts [:tostr $t];
:local hours [:pick $ts 0 2];
:local mins [:pick $ts 3 5];
:local secs [:pick $ts 6 8];

# ═══════════════════════════════════════════════════════════════════════════════
#                        3. :timestamp COMMAND
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 3.1: Timestamp format is WWWWwDd:HH:MM:SS.nanoseconds
:local ts [:timestamp];
:put [:typeof $ts];                      # => time
:put $ts;                                # => 2920w5d07:03:45.210877008

# RULE 3.2: Parse timestamp components
:local tsStr [:tostr $ts];
:local wPos [:find $tsStr "w"];
:local dPos [:find $tsStr "d"];
:local weeks [:pick $tsStr 0 $wPos];     # => 2920
:local days [:pick $tsStr ($wPos + 1) $dPos]; # => 5

# RULE 3.3: Compare timestamps (newer > older)
:local ts1 [:timestamp];
:delay 1s;
:local ts2 [:timestamp];
:put ($ts2 > $ts1);                      # => true

# ═══════════════════════════════════════════════════════════════════════════════
#                        4. :tonsec COMMAND (CRITICAL!)
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 4.1: :tonsec returns NANOSECONDS (NOT seconds!)
:put [:tonsec 1s];                       # => 1000000000 (1 billion!)
:put [:tonsec 1ms];                      # => 1000000
:put [:tonsec 1m];                       # => 60000000000
:put [:tonsec 1h];                       # => 3600000000000

# RULE 4.2: Convert to seconds - DIVIDE BY 1,000,000,000
:local ns [:tonsec 1h];
:local sec ($ns / 1000000000);           # => 3600

# RULE 4.3: Get epoch seconds from timestamp
:local epochNs [:tonsec [:timestamp]];
:local epochSec ($epochNs / 1000000000); # => seconds since 1970

# RULE 4.4: Calculate days from timestamp
:local daysSinceEpoch ($epochSec / 86400);

# ═══════════════════════════════════════════════════════════════════════════════
#                        5. :totime COMMAND (DURATION FORMS)
# ═══════════════════════════════════════════════════════════════════════════════
# For ISO date/time forms (7.18+ adds limited ISO TZ tolerance), see Section 6.

# RULE 5.1: Convert string to time type
:put [:totime "1h"];                     # => 01:00:00
:put [:totime "1h30m"];                  # => 01:30:00
:put [:totime "01:30:00"];               # => 01:30:00
:put [:totime "90m"];                    # => 01:30:00

# RULE 5.2: Complex durations
:put [:totime "1w2d3h4m5s"];             # => 1w2d03:04:05
:put [:totime "500ms"];                  # => 00:00:00.500

# RULE 5.3: Equivalence
:put ([:totime "1h"] = [:totime "60m"]); # => true

# RULE 5.4: Numeric strings parse as seconds-since-epoch (undocumented)
:put [:totime "1700000000"];             # => 2810w5d22:13:20
:put [:totime "0"];                      # => 00:00:00
:put [:totime "-1"];                     # => -00:00:01

# RULE 5.5: nil is the failure sentinel - check via :typeof, NOT = nil
:local t [:totime "garbage"];
:put [:typeof $t];                       # => nil
:put ($t = nil);                         # => false  (!! never use = nil)
:put ([:typeof $t] = "nil");             # => true   (correct nil-check)

# ═══════════════════════════════════════════════════════════════════════════════
#                  6. ISO TIMESTAMP PARSING (7.18+)
# ═══════════════════════════════════════════════════════════════════════════════
# 7.18 changelog: "console - allow ISO timezone format in :totime command".
# Implementation is partial: tokenization tolerance, NOT semantic TZ awareness.
# Empirically verified on 7.23rc2.

# RULE 6.1: T-separator (canonical ISO 8601) IS REJECTED — returns nil silently
:put [:totime "2026-04-30T12:00:00Z"];      # => "" :: nil  (!!)
:put [:totime "2026-04-30T12:00:00"];       # => "" :: nil
:put [:totime "2026-04-30T12:00:00+02:00"]; # => "" :: nil
# JavaScript toISOString(), Python isoformat() default, .NET DateTimeOffset
# all emit T-separator. Convert to space delimiter before passing to :totime.

# RULE 6.2: Space delimiter is REQUIRED for date+time
:put [:totime "2026-04-30 12:00:00"];       # => 2939w12:00:00 :: time
:put [:totime "2026-04-30 12:00:00 Z"];     # => 2939w12:00:00 :: time (TZ swallowed)
:put [:totime "2026-04-30 12:00:00+0200"];  # => 2939w12:00:00 :: time

# RULE 6.3: TZ marker is COSMETIC — silently STRIPPED, no offset math (7.18+)
# These two return IDENTICAL value (no 2h shift applied):
:put ([:totime "2026-04-30 14:00:00"] = [:totime "2026-04-30 14:00:00+0200"]);
                                            # => true  (!! TZ ignored)
# Do NOT rely on :totime to convert TZ-aware timestamps to local/UTC.
# Apply TZ offsets manually: ($raw - 02:00:00) for UTC from +0200.

# RULE 6.4: TZ-marker tokens silently accepted (no validation)
:put [:totime "2026-04-30 12:00:00 UTC"];   # => 2939w12:00:00 (token swallowed)
:put [:totime "2026-04-30 12:00:00 PST"];   # => 2939w12:00:00 (token swallowed)
:put [:totime "2026-04-30 12:00:00 garbage"];# => 2939w12:00:00 (!! garbage ok)
:put [:totime "2026-04-30 12:00:00 +abc"];  # => 2939w12:00:00 (!! invalid ok)

# RULE 6.5: SPACE-DETACHED +HH:MM (with colon) FAILS — asymmetric rule
:put [:totime "2026-04-30 12:00:00 +02:00"];# => "" :: nil   (fails)
:put [:totime "2026-04-30 12:00:00 -05:30"];# => 2939w12:00:00 (works)
:put [:totime "2026-04-30 12:00:00+02:00"]; # => 2939w12:00:00 (attached works)
:put [:totime "2026-04-30 12:00:00 +0200"]; # => 2939w12:00:00 (no-colon works)
# Safest TZ form: +HHMM (no colon), no leading space. Or omit TZ entirely.

# RULE 6.6: Sub-second precision is dropped when date prefix is present
:put [:totime "2026-04-30 12:00:00.123"];   # => 2939w12:00:00 (.123 dropped!)
:put [:totime "12:00:00.500"];              # => 12:00:00.500 (preserved time-only)

# RULE 6.7: Time-only with TZ - TZ must be ATTACHED (no space)
:put [:totime "12:00:00Z"];                 # => 12:00:00 (ok)
:put [:totime "12:00:00+0200"];             # => 12:00:00 (ok, TZ ignored)
:put [:totime "12:00:00 Z"];                # => "" :: nil (space-detached fails)

# RULE 6.8: Date-only parses to weeks-since-1970-01-01
:put [:totime "1970-01-01"];                # => 00:00:00 (epoch zero)
:put [:totime "2026-04-30"];                # => 2939w00:00:00
:put [:totime "2099-12-31"];                # => 6783w00:00:00

# RULE 6.9: Invalid FORMS return nil; out-of-range NUMBERS silently overflow
:put [:totime "not-iso"];                   # => "" :: nil
:put [:totime "2026-04-30T25:00:00Z"];      # => "" :: nil (T-form)
:put [:totime "2026/04/30 12:00:00"];       # => "" :: nil (slash separator)
:put [:totime "20260430T120000Z"];          # => "" :: nil (no separators)
# But out-of-range numeric fields silently OVERFLOW (no validation):
:put [:totime "2026-13-30 12:00:00"];       # => 2978w2d12:00:00 (month 13 = Jan+1y!)
:put [:totime "2026-04-31 12:00:00"];       # => 2939w1d12:00:00 (day 31 = May 1)
:put [:totime "2026-02-30 12:00:00"];       # => 2930w4d12:00:00 (day 30 = Mar 2)
# Always validate ranges yourself if input is untrusted.

# RULE 6.10: Round-trip via :tostr drops TZ + millis
:put [:tostr [:totime "2026-04-30 12:00:00.123Z"]];  # => 2939w12:00:00
# :totime/:tostr is NOT a value-preserving round-trip for TZ-marked input.

# RULE 6.11: Recommended ISO ingest pattern (T-form -> space + nil-check)
# Note: BOTH branches use [:typeof ...] for nil-testing — direct ($p != nil) is
# unreliable when $p is nil (returns true even when nil — see RULE 5.5).
:global parseIso8601 do={
  :local s $1;
  :local p [:find $s "T"];
  :if ([:typeof $p] != "nil") do={
    :set s ([:pick $s 0 $p] . " " . [:pick $s ($p+1) [:len $s]]);
  }
  :local t [:totime $s];
  :if ([:typeof $t] = "nil") do={ :error ("bad ISO timestamp: " . $1); }
  :return $t;
}
:put [$parseIso8601 "2026-04-30T12:00:00Z"];       # => 2939w12:00:00
:put [$parseIso8601 "2026-04-30 12:00:00"];        # => 2939w12:00:00

# ═══════════════════════════════════════════════════════════════════════════════
#                     7. TIME ARITHMETIC (CRITICAL!)
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 7.1: Time extends beyond 24h with day prefix!
:put (23:00:00 + 2:00:00);               # => 1d01:00:00 (NOT wrapped!)
:put (12h + 24h);                        # => 1d12:00:00
:put (12h + 36h);                        # => 2d00:00:00

# RULE 7.2: Time subtraction
:put (1d - 1h);                          # => 23:00:00
:put (1w - 1d);                          # => 6d00:00:00

# RULE 7.3: Negative time IS VALID
:put (1h - 2h);                          # => -01:00:00
:put ((1h - 2h) < 0s);                   # => true

# RULE 7.4: Multiplication and division
:put (1h * 2);                           # => 02:00:00
:put (2h / 2);                           # => 01:00:00
:put (1h / 60);                          # => 00:01:00 (1 minute)

# RULE 7.5: Equivalences
:put (24h = 1d);                         # => true
:put (7d = 1w);                          # => true

# ═══════════════════════════════════════════════════════════════════════════════
#                        8. UPTIME
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 8.1: Uptime is time type in v7
:local uptime [/system resource get uptime];
:put [:typeof $uptime];                  # => time

# RULE 8.2: Directly comparable
:if ($uptime > 1d) do={ :put "Running >1 day" };
:if ($uptime < 5m) do={ :put "Recently rebooted" };

# RULE 8.3: Convert to days
:local uptimeSec ([:tonsec $uptime] / 1000000000);
:local uptimeDays ($uptimeSec / 86400);

# ═══════════════════════════════════════════════════════════════════════════════
#                     9. ADDRESS-LIST TIMEOUT
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 9.1: Timeout entries are dynamic (RAM-only, lost on reboot!)
/ip firewall address-list add list=test address=10.0.0.1 timeout=1h;

# RULE 9.2: Timeout is time type
:local entry [/ip firewall address-list find address=10.0.0.1];
:local timeout [/ip firewall address-list get $entry timeout];
:put [:typeof $timeout];                 # => time

# RULE 9.3: Maximum timeout is ~35w3d
/ip firewall address-list add list=test address=10.0.0.2 timeout=35w;
# Actual timeout: 34w6d23:59:59

# RULE 9.4: Static entries have nil timeout
:local staticTimeout [/ip firewall address-list get $staticEntry timeout];
:put [:typeof $staticTimeout];           # => nil

# ═══════════════════════════════════════════════════════════════════════════════
#                    10. CERTIFICATE DATES (INCONSISTENT!)
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 10.1: expires-after is REMAINING DURATION (time type)
:local expiresAfter [/certificate get $cert expires-after];
:put [:typeof $expiresAfter];            # => time
:if ($expiresAfter < 7d) do={ :log warning "Cert expiring soon!" };

# RULE 10.2: invalid-after uses ISO FORMAT (YYYY-MM-DD HH:MM:SS) in v7!
:local invalidAfter [/certificate get $cert invalid-after];
:put [:typeof $invalidAfter];            # => str
:put $invalidAfter;                      # => 2025-12-25 12:00:00

# RULE 10.3: expired property is nil (use duration check)
:local isExpired [/certificate get $cert expired]; # => nil
# 'expires-after' is DURATION REMAINING (e.g. 4w1d...)
:if ($expiresAfter < 1h) do={ :log warning "Expiring soon!" };


# RULE 10.4: Calculate days until expiration
:local daysLeft ([:tonsec $expiresAfter] / 1000000000 / 86400);

# ═══════════════════════════════════════════════════════════════════════════════
#                       11. FILE DATES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 11.1: last-modified is string (YYYY-MM-DD HH:MM:SS)
:local files [/file print as-value where name="test.txt"];
:local lastMod ($files->0->"last-modified");
:put [:typeof $lastMod];                 # => str
:put $lastMod;                           # => 2025-12-23 07:04:12

# ═══════════════════════════════════════════════════════════════════════════════
#                       12. SCHEDULER DATES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 12.1: start-date is string (YYYY-MM-DD in v7.10+)
:local startDate [/system scheduler get myTask start-date];
:put [:typeof $startDate];               # => str

# RULE 12.2: start-time is STRING (not time type!)
:local startTime [/system scheduler get myTask start-time];
:put [:typeof $startTime];               # => str

# RULE 12.3: interval is time type
:local interval [/system scheduler get myTask interval];
:put [:typeof $interval];                # => time

# ═══════════════════════════════════════════════════════════════════════════════
#                    13. SCRIPT PROPERTIES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 13.1: last-started is string (YYYY-MM-DD HH:MM:SS)
:local lastStarted [/system script get myScript last-started];
:put [:typeof $lastStarted];             # => str
:put $lastStarted;                       # => 2025-12-23 07:04:53

# RULE 13.2: run-count is num
:local runCount [/system script get myScript run-count];
:put [:typeof $runCount];                # => num

# ═══════════════════════════════════════════════════════════════════════════════
#                    14. TIMEZONE & NTP
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 14.1: gmt-offset is num (NOT time!)
:local offset [/system clock get gmt-offset];
:put [:typeof $offset];                  # => num (seconds)

# RULE 14.2: NTP status is string
:local status [/system ntp client get status];
:put [:typeof $status];                  # => str
:put ($status = "synchronized");         # => true/false

# RULE 14.3: Wait for NTP sync pattern
:local syncTimeout 0;
:while (([/system/ntp/client/get status] != "synchronized") && $syncTimeout < 30) do={
  :delay 1s; :set syncTimeout ($syncTimeout + 1);
};

# ═══════════════════════════════════════════════════════════════════════════════
#                 15. VERSION-AGNOSTIC DATE PARSER
# ═══════════════════════════════════════════════════════════════════════════════

# Works with both old (MMM/DD/YYYY) and new (YYYY-MM-DD) formats
:global parseDate do={
  :local d $1;
  :local months {"jan"=1;"feb"=2;"mar"=3;"apr"=4;"may"=5;"jun"=6;
                 "jul"=7;"aug"=8;"sep"=9;"oct"=10;"nov"=11;"dec"=12};
  :local y; :local m; :local day;
  :if ([:pick $d 4 5] = "-") do={
    :set y [:pick $d 0 4];
    :set m [:pick $d 5 7];
    :set day [:pick $d 8 10];
  } else={
    :local ms [:pick $d 0 3];
    :set m ($months->$ms);
    :if ($m < 10) do={:set m ("0" . $m)} else={:set m [:tostr $m]};
    :set day [:pick $d 4 6];
    :set y [:pick $d 7 11];
  };
  :return {"year"=$y; "month"=$m; "day"=$day; "iso"=($y . "-" . $m . "-" . $day)};
};

# Usage:
:local parsed [$parseDate [/system clock get date]];
:put ($parsed->"iso");                   # => 2025-12-23

# ═══════════════════════════════════════════════════════════════════════════════
#                    16. EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 16.1: Negative time is valid
:put (1h - 2h);                          # => -01:00:00
:put ((1h - 2h) < 0s);                   # => true

# RULE 16.2: Millisecond precision
:put 500ms;                              # => 00:00:00.500
:put (500ms < 1s);                       # => true

# RULE 16.3: Large time values supported
:put 999w;                               # => 999w00:00:00

# RULE 16.4: Leap year calculation
:global isLeapYear do={
  :local y [:tonum $1];
  :if (($y % 4 = 0) && (($y % 100 != 0) || ($y % 400 = 0))) do={:return true};
  :return false;
};

# ═══════════════════════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════════════════════
#                       17. LOG DATES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 17.1: Log time is str (ISO format in v7)
:local t [/log get $id time];
:put [:typeof $t];                       # => str
:put $t;                                 # => 2025-12-23 07:13:04

# RULE 17.2: Filtering
# /log print as-value count=5 FAILS.
# Use 'where' or 'find':
:local logs [/log print as-value where topics~"system"];

#                     DATETIME LLM ANTI-PATTERNS
# ═══════════════════════════════════════════════════════════════════════════════

# ┌───────────────────────────────────────────────────────────────────────────────┐
# │ ✗ Date format is MMM/DD/YYYY → v7.10+ uses YYYY-MM-DD                         │
# │ ✗ :tonsec returns seconds → Returns NANOSECONDS (÷1e9)                        │
# │ ✗ :timestamp is Unix epoch → Returns WWWWwDd:HH:MM:SS.ns                      │
# │ ✗ Time wraps at 24h → Extends with day prefix (1d01:00:00)                    │
# │ ✗ Cert dates match clock format → Certs use ISO YYYY-MM-DD (v7.10+)           │
# │ ✗ Log print as-value has count  → as-value fails with count (use where)       │
# │ ✗ Log time is time type         → It's str type (ISO format)                  │
# │ ✗ Uptime is string in v7 → It's time type, directly comparable                │
# │ ✗ scheduler start-time is time type → It's string!                            │
# │ ✗ last-started is time type → It's string!                                    │
# │ ✗ gmt-offset is time type → It's num (seconds)                                │
# │ ✗ Address-list timeout persists → Dynamic entries lost on reboot              │
# │ ✗ NTP syncs instantly after boot → Clock starts at 1970, wait for sync        │
# │ ✗ :totime parses ISO T-form ("2026-04-30T12:00:00Z") → returns nil (use space)│
# │ ✗ :totime applies TZ offset → TZ stripped silently, no offset math (7.18+)    │
# │ ✗ :totime accepts +HH:MM only attached → " +02:00" fails; "+0200" safest      │
# │ ✗ :totime millis preserved → date-prefixed forms drop sub-second (.123 lost)  │
# │ ✗ :totime nil checked via = nil → false even if nil; use [:typeof $t]="nil"   │
# └───────────────────────────────────────────────────────────────────────────────┘
