# ┌─────────────────────────────────────────────────────────────────────────────┐
# │              RouterOS 7 DateTime Reference (Verified 7.21+)                 │
# │                    Empirically Tested - 500+ Tests                          │
# └─────────────────────────────────────────────────────────────────────────────┘
# Version: 1.0 | Target: RouterOS 7.10+ | Last Verified: 2025-12-23

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
#                        5. :totime COMMAND
# ═══════════════════════════════════════════════════════════════════════════════

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

# ═══════════════════════════════════════════════════════════════════════════════
#                     6. TIME ARITHMETIC (CRITICAL!)
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 6.1: Time extends beyond 24h with day prefix!
:put (23:00:00 + 2:00:00);               # => 1d01:00:00 (NOT wrapped!)
:put (12h + 24h);                        # => 1d12:00:00
:put (12h + 36h);                        # => 2d00:00:00

# RULE 6.2: Time subtraction
:put (1d - 1h);                          # => 23:00:00
:put (1w - 1d);                          # => 6d00:00:00

# RULE 6.3: Negative time IS VALID
:put (1h - 2h);                          # => -01:00:00
:put ((1h - 2h) < 0s);                   # => true

# RULE 6.4: Multiplication and division
:put (1h * 2);                           # => 02:00:00
:put (2h / 2);                           # => 01:00:00
:put (1h / 60);                          # => 00:01:00 (1 minute)

# RULE 6.5: Equivalences
:put (24h = 1d);                         # => true
:put (7d = 1w);                          # => true

# ═══════════════════════════════════════════════════════════════════════════════
#                        7. UPTIME
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 7.1: Uptime is time type in v7
:local uptime [/system resource get uptime];
:put [:typeof $uptime];                  # => time

# RULE 7.2: Directly comparable
:if ($uptime > 1d) do={ :put "Running >1 day" };
:if ($uptime < 5m) do={ :put "Recently rebooted" };

# RULE 7.3: Convert to days
:local uptimeSec ([:tonsec $uptime] / 1000000000);
:local uptimeDays ($uptimeSec / 86400);

# ═══════════════════════════════════════════════════════════════════════════════
#                     8. ADDRESS-LIST TIMEOUT
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 8.1: Timeout entries are dynamic (RAM-only, lost on reboot!)
/ip firewall address-list add list=test address=10.0.0.1 timeout=1h;

# RULE 8.2: Timeout is time type
:local entry [/ip firewall address-list find address=10.0.0.1];
:local timeout [/ip firewall address-list get $entry timeout];
:put [:typeof $timeout];                 # => time

# RULE 8.3: Maximum timeout is ~35w3d
/ip firewall address-list add list=test address=10.0.0.2 timeout=35w;
# Actual timeout: 34w6d23:59:59

# RULE 8.4: Static entries have nil timeout
:local staticTimeout [/ip firewall address-list get $staticEntry timeout];
:put [:typeof $staticTimeout];           # => nil

# ═══════════════════════════════════════════════════════════════════════════════
#                     9. CERTIFICATE DATES (INCONSISTENT!)
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 9.1: expires-after is REMAINING DURATION (time type)
:local expiresAfter [/certificate get $cert expires-after];
:put [:typeof $expiresAfter];            # => time
:if ($expiresAfter < 7d) do={ :log warning "Cert expiring soon!" };

# RULE 9.2: invalid-after uses ISO FORMAT (YYYY-MM-DD HH:MM:SS) in v7!
:local invalidAfter [/certificate get $cert invalid-after];
:put [:typeof $invalidAfter];            # => str
:put $invalidAfter;                      # => 2025-12-25 12:00:00

# RULE 9.3: expired property is nil (use duration check)
:local isExpired [/certificate get $cert expired]; # => nil
# 'expires-after' is DURATION REMAINING (e.g. 4w1d...)
:if ($expiresAfter < 1h) do={ :log warning "Expiring soon!" };


# RULE 9.4: Calculate days until expiration
:local daysLeft ([:tonsec $expiresAfter] / 1000000000 / 86400);

# ═══════════════════════════════════════════════════════════════════════════════
#                        10. FILE DATES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 10.1: last-modified is string (YYYY-MM-DD HH:MM:SS)
:local files [/file print as-value where name="test.txt"];
:local lastMod ($files->0->"last-modified");
:put [:typeof $lastMod];                 # => str
:put $lastMod;                           # => 2025-12-23 07:04:12

# ═══════════════════════════════════════════════════════════════════════════════
#                        11. SCHEDULER DATES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 11.1: start-date is string (YYYY-MM-DD in v7.10+)
:local startDate [/system scheduler get myTask start-date];
:put [:typeof $startDate];               # => str

# RULE 11.2: start-time is STRING (not time type!)
:local startTime [/system scheduler get myTask start-time];
:put [:typeof $startTime];               # => str

# RULE 11.3: interval is time type
:local interval [/system scheduler get myTask interval];
:put [:typeof $interval];                # => time

# ═══════════════════════════════════════════════════════════════════════════════
#                     12. SCRIPT PROPERTIES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 12.1: last-started is string (YYYY-MM-DD HH:MM:SS)
:local lastStarted [/system script get myScript last-started];
:put [:typeof $lastStarted];             # => str
:put $lastStarted;                       # => 2025-12-23 07:04:53

# RULE 12.2: run-count is num
:local runCount [/system script get myScript run-count];
:put [:typeof $runCount];                # => num

# ═══════════════════════════════════════════════════════════════════════════════
#                     13. TIMEZONE & NTP
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 13.1: gmt-offset is num (NOT time!)
:local offset [/system clock get gmt-offset];
:put [:typeof $offset];                  # => num (seconds)

# RULE 13.2: NTP status is string
:local status [/system ntp client get status];
:put [:typeof $status];                  # => str
:put ($status = "synchronized");         # => true/false

# RULE 13.3: Wait for NTP sync pattern
:local syncTimeout 0;
:while (([/system/ntp/client/get status] != "synchronized") && $syncTimeout < 30) do={
  :delay 1s; :set syncTimeout ($syncTimeout + 1);
};

# ═══════════════════════════════════════════════════════════════════════════════
#                  14. VERSION-AGNOSTIC DATE PARSER
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
#                     15. EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 15.1: Negative time is valid
:put (1h - 2h);                          # => -01:00:00
:put ((1h - 2h) < 0s);                   # => true

# RULE 15.2: Millisecond precision
:put 500ms;                              # => 00:00:00.500
:put (500ms < 1s);                       # => true

# RULE 15.3: Large time values supported
:put 999w;                               # => 999w00:00:00

# RULE 15.4: Leap year calculation
:global isLeapYear do={
  :local y [:tonum $1];
  :if (($y % 4 = 0) && (($y % 100 != 0) || ($y % 400 = 0))) do={:return true};
  :return false;
};

# ═══════════════════════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════════════════════
#                        16. LOG DATES
# ═══════════════════════════════════════════════════════════════════════════════

# RULE 16.1: Log time is str (ISO format in v7)
:local t [/log get $id time];
:put [:typeof $t];                       # => str
:put $t;                                 # => 2025-12-23 07:13:04

# RULE 16.2: Filtering
# /log print as-value count=5 FAILS.
# Use 'where' or 'find':
:local logs [/log print as-value where topics~"system"];

#                     DATETIME LLM ANTI-PATTERNS
# ═══════════════════════════════════════════════════════════════════════════════

# ┌───────────────────────────────────────────────────────────────────────────────┐
# │ ✗ Date format is MMM/DD/YYYY → v7.10+ uses YYYY-MM-DD                        │
# │ ✗ :tonsec returns seconds → Returns NANOSECONDS (÷1e9)                       │
# │ ✗ :timestamp is Unix epoch → Returns WWWWwDd:HH:MM:SS.ns                     │
# │ ✗ Time wraps at 24h → Extends with day prefix (1d01:00:00)                   │
# │ ✗ Cert dates match clock format → Certs use ISO YYYY-MM-DD (v7.10+)          │
│ ✗ Log print as-value has count  → as-value fails with count (use where)        │
│ ✗ Log time is time type         → It's str type (ISO format)                   │
# │ ✗ Uptime is string in v7 → It's time type, directly comparable              │
# │ ✗ scheduler start-time is time type → It's string!                          │
# │ ✗ last-started is time type → It's string!                                  │
# │ ✗ gmt-offset is time type → It's num (seconds)                              │
# │ ✗ Address-list timeout persists → Dynamic entries lost on reboot            │
# │ ✗ NTP syncs instantly after boot → Clock starts at 1970, wait for sync      │
# └───────────────────────────────────────────────────────────────────────────────┘
