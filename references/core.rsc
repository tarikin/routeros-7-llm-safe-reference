## RouterOS 7 Mini-Reference (Token-Efficient)
# Single-line comments only (#). No multiline comments. 
# Avoid undefined vars => compile error. 
# Use semicolons if you add inline comments.

# BASICS & LINE STRUCTURE
:global gVar; :set gVar 123;
:local lVar "abc";
# DATA TYPES & CONVERSION
# Core: num (numbers), str (strings), bool, array, nil (nothing), time
# Network: ip, ip6, ip-prefix, ip6-prefix
# Note: MAC addresses are typed as str
# Functions return 'code' type
:put ([:typeof $gVar]); ; # => num,str,bool,array,nil,time,ip,ip-prefix,ip6,ip6-prefix,code

# TYPE CONVERSION
:put ([:tonum "123"]); ; # => 123 (str->num)
:put ([:tostr 123]); ; # => "123" (num->str)
:put ([:toip "192.168.1.1"]); ; # => 192.168.1.1 (str->ip)
:put ([:tobool "yes"]); ; # => true on 7.22+; nil on <7.22 (case-strict, exact match)
:put ([:toarray "a,b,c" delimiter=","]); ; # => {"a";"b";"c"}
:put ([:pick "abc" 1 2]); ; # => "b" (substring)
:put ([:find "abc" "b"]); ; # => 1 (position)
:put ([:len "abc"]); ; # => 3 (length)
:put ([:timestamp]); ; # => current timestamp
:put ([:time]); ; # => seconds since epoch
# Line-ending normalization standalones (7.14+) — equivalent to :convert transform=lf/crlf
:put ([:tolf "a\r\nb"]); ; # => "a\nb"     (CRLF / bare CR -> LF)
:put ([:tocrlf "a\nb"]); ; # => "a\r\nb"   (LF / bare CR -> CRLF; idempotent on CRLF)
# Note: :tolower / :toupper do NOT exist; use :convert transform=lc / transform=uc (7.16+)
# :nothing keyword — explicit empty/sentinel value (typeof=nil, len=0, concat→"")
:put [:typeof [:nothing]];   ; # => nil
:put [:len [:nothing]];      ; # => 0
:put ([:nothing] . "tail");  ; # => "tail"   (concat treats it as "")
:if (condition) do={ :put ("true") } else={ :put ("false") };

# Code blocks use curly braces and require semicolons
{
    :local x 1;
    :put ("x = " . $x);  # String concatenation with . operator
}

# Line joining example:
:if ($a=true \
  && $b=false) do={ 
    :put ("combo");  # Semicolon required inside code blocks
};

# String concatenation requires parentheses
:put ("Hello " . "world");  # Correct
:put "Hello " . "world";    # Will cause error

# End lines with semicolons or a newline. 

# PATH & SUBPATH
# "/"=root. Spaces/slashes merge => tokens. E.g. "/ip address" ~ "/ip/address" => ["ip","address"]
# Double slash => empty token => error. Trailing slash w/o next token => error. Slash in cmd-params => error
# Command after last token: "/ip address add" ~ "/ip/address/add"
# exValid: "/ip firewall filter add", "/ip/firewall filter add", "/  ip firewall filter add"
# exInvalid: "/ip//firewall", "/ip/firewall/filter/add/", "/ip/firewall/ /filter/add"

# ARRAYS & DICT
:global arr [];
:set ($arr->0) {"ip"="1.1.1.1";"desc"="DNS"};
:put [:len $arr]; ; # => length
:put ($arr->0->"ip"); ; # => "1.1.1.1"
:put ({1;2;3},4); ; # => 1;2;3;4
:set ($arr->0->"quoted-key") "value";
:global dict [];
:set ($dict->"config") {"key"="val"};
:put ([$dict]->"config"->"key");

# SCOPES & VARS
:local x 0;
:while ($x<3) do={ :set x ($x+1); :put $x; };
{
  :local temp "block-scope-only";
}

# OPERATORS & STRINGS
# + - * / % < > = != <= >= && || ~ & | ^ << >>
:put (192.168.0.100 & 255.255.255.0);
:put (1.1.1.1/32 in 1.0.0.0/8); ; # => true/false
:put [:find "abc" "b"]; ; # => 1
:put [:pick "abc" 1 2]; ; # => "b"
:put [:tonum "1234"]; ; # => 1234
:put [:tostr 1234]; ; # => "1234"
:put [:timestamp]; ; # e.g. 2735w21:41:43.123456789
:for i from=1 to=3 do={ :put $i };

# STRING ESCAPING
# Use backslashes to escape special chars
:local escExample "Line1\nLine2 with \"quotes\", backslash\\, tab\t, and carriageReturn\r";
:put $escExample;

# HEX ESCAPES (UTF-8 / EMOJI, ETC.)
:local hexStr "Some text \F0\9F\XX\YY more text"; :put $hexStr;

# PRINT & WHERE
/ip route print where gateway=1.1.1.1;
:put [/system script print as-value];
:global fw ( [/ip firewall filter print as-value]->0 );
:put [:serialize to=json value=$fw];

# :grep (7.14+) — runs script= and counts STDOUT lines matching pattern= regex
# NOT a string utility. script= is RouterOS source EXECUTED. pattern= is regex (case-sensitive).
# Stdout from script is still echoed to caller. Returns num (line-count, not match-count).
:put [:grep script="/interface print" pattern="ether"];   ; # e.g. => 2
:put [:grep script=":put a; :put b; :put c" pattern="b"]; ; # => 1
# script= accepts: string OR code-block ({...}). Does NOT accept :parse'd code, fn var, num, bool.
# pattern="" → "invalid regex pattern" (error). For substring search use [:find $s "needle"] or ~.

# JSON & DSV
:put [:serialize to=json value=$arr];
:put [:deserialize from=json value="[\"x\",\"y\"]"];
:put [:serialize to=dsv value=$dict delimiter=";" order=("config")];
:put [:deserialize from=dsv value="a;b;c\n1;2;3" delimiter=";" options=dsv.plain];

# TIME & DATE
/system clock get date; ; # => e.g. 2025-12-23 (ISO)
:local d [/system clock get date];
:local y [:pick $d 0 4];
:local m [:pick $d 5 7];
:local day [:pick $d 8 10];

# LOG & BEEP
:beep frequency=300 length=500ms;
/log print as-value where buffer="logParse";
:global logParseVar "";
:if ([:find [:tostr $logParseVar] "failure"] != nil) do={ :put "login failure" };

# SCRIPTS & ENV
/system script run "myScript";
/environment print;        # use this — NOT the [:environment] callable (returns nil, no-op).
# [:terminal] / [:environment] are interactive-only stubs in script context (return nil).

# MERGE ARRAYS
:global arr2 ({1;2;3},5);

# CLEAR LOG
/system logging action {
   :local old [get logParse memory-lines];
   set logParse memory-lines=1;
   set logParse memory-lines=$old;
}

# BEHAVIOR & EXIT
# :lock (7.16+, interactive only) — locks the local console screen; takes optional delay=<time>
# In script context (/import, ros-deploy, /system script run) :lock is a NO-OP that returns nil
# immediately (verified: [:time {:lock delay=5s}] elapses ~20us). Use :delay if you want a pause.
# :lock; :lock delay=10s; :lock 10s;        # all return nil in scripts
:onerror err in={ :resolve "no-such-domain" } do={ :put "Error => $err" };
# :resolve type= (7.15+) selects ADDRESS FAMILY {ipv4|ipv6|any|any6}, NOT DNS record-type.
# Record-type names (A, AAAA, MX, TXT, NS, CNAME, SOA, SRV, PTR) are REJECTED.
:put [:resolve "google.com" type=ipv4];   # => 142.251.142.238 (typeof=ip)
:put [:resolve "google.com" type=ipv6];   # => 2a00:1450:400f:802::200e (typeof=ip6)
# :resolve <ipliteral> does PTR automatically:
:put [:resolve "8.8.8.8"];                # => dns.google.
:if ($abortCondition=true) do={ :log error "Aborting"; :quit; };

# DO { } WHILE=(condition)
:do {
  /system/backup/cloud/remove-file [find];
  :delay 5;
  :log info "Cloud backups removed.";
} while=([/system/backup/cloud/print count-only]>0);

# FOREACH & IF / OR
:foreach i in="dns" do={
  :if ([:typeof $i]="str" || $i~"regex") do={ :put "Is string" };
};

# :range (7.17+) — generate ascending/descending integer arrays
# Signature: [:range from=<int> to=<int>]  (NO step= parameter; use :for for stride)
:put [:range from=1 to=5];          ; # => 1;2;3;4;5
:put [:range from=5 to=1];          ; # => 5;4;3;2;1   (descending — :foreach iterates in order)
:put [:range from=7 to=7];          ; # => 7           (single-element array)
:put [:range -3 3];                 ; # => -3;-2;-1;0;1;2;3   (2-positional from to also works)
# Hard cap: 1,000,000 elements. Beyond that → "size of the ranged array is too large".
:foreach i in=[:range from=1 to=10] do={ :put $i };  # canonical iteration idiom
# step= does NOT exist on :range; emulate via :foreach + modulo, or use :for from=A to=B step=S:
:for i from=1 to=10 step=2 do={ :put $i };           ; # => 1 3 5 7 9
# IPv6 NOT accepted; IP/time auto-coerced to int. Result element type is num.
# :rndnum / :rndstr — random primitives
:put [:rndnum from=1 to=10];        ; # => 1..10 inclusive (typeof=num)
:put [:rndstr length=8];            ; # => 8 chars from [A-Za-z0-9] (default len=16)
# CAUTION: [:rndnum from=10 to=1] does NOT error; returns garbage int64. Always order from<=to.
# :rndstr charset is FIXED; no source=/alphabet=/chars=/type= parameters on 7.23rc2.

# RETRY COMMAND
:if ([/file print count-only where name=$ramdiskName type=disk]=0) do={
  :retry command={
    /disk add type=tmpfs tmpfs-max-size=$ramdiskMaxSize slot=$ramdiskName comment="RAM disk"
  } delay=5s max=5 on-error={
    :log error "Failed to create RAM disk";
    :error "Critical Error";
  };
};

# EXECUTE (async) — see also async.rsc for full :execute / :time / :jobname surface
# :exec is a parser alias of :execute (same arguments, same return type=id).
:execute ("/certificate export-certificate $cert export-passphrase=\"$pass\" file-name=\"out_$cert\" type=pkcs12");
:delay 3s; :log info "Exported $cert";

# IMPORT .rsc
:do {
  :log info "Importing file...";
  /import file-name=$someFileName;
} on-error={
  :log error "Failed import";
};

# EXAMPLE: WAIT FOR NTP SYNC
{
  :if ([:len [/system/ntp/client/get server]]=0) do={
    /system/ntp/client/set server="time.server";
  };
  :local syncTimeout 0;
  :while (([/system/ntp/client/get status]!="synchronized") && $syncTimeout<30) do={
    :delay 1s; :set syncTimeout ($syncTimeout+1);
  };
  :if ([/system/ntp/client/get status]!="synchronized") do={
    :log error "NTP not synced. :quit";
    :quit;
  };
  :log info "NTP synced.";
}

# TOOL FETCH + WAIT FILE
:retry command={
  /tool fetch url="https://..." mode=https keep-result=yes dst-path="fetchedFile"
} delay=3s max=3 on-error={ :log error "Fetch failed" };
:local iFileReady false; :local timer 0;
:while (!$iFileReady && $timer<10) do={
  :if ([/file print count-only where name="fetchedFile"]>0) do={ :set iFileReady true } else={
    :delay 1s; :set timer ($timer+1);
  }
};

# TIPS
# - Place comments on separate lines or after semicolon 
# - :quit ends script 
# - :retry + on-error to handle repeated attempts 
# - do{} while=(expr) for repeated loops 
# - "execute" is async unless "as-string" used 
# - Keep code minimal to avoid LLM guess/hallucinations
