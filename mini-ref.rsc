## RouterOS 7 Mini-Reference (Token-Efficient)
# Single-line comments only (#). No multiline comments. 
# Avoid undefined vars => compile error. 
# Use semicolons if you add inline comments.

# BASICS & LINE STRUCTURE
:global gVar; :set gVar 123;
:local lVar "abc";
:put [:typeof $gVar]; ; # => num,str,array,nil
:if (condition) do={ :put "true" } else={ :put "false" };
# Line joining example:
:if ($a=true \
  && $b=false) do={ :put "combo" };
# End lines with semicolons or a newline. 

# PATH & SUBPATH
# / => root.  Whitespace+slash combos collapse to tokens.  E.g. "/ip/address" 
# ~ "/ip address" ~ "/ip address/" ~ "/    ip/   address/" => same path tokens ("ip" > "address").
# A mid-path slash with no token => error ("/ip /" => invalid).
# Commands come after final subpath: "/ip address add" or "/ip/address add" => same command.
# Trailing slash after command => error ("/ip address add/" => bad).

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

# JSON & DSV
:put [:serialize to=json value=$arr];
:put [:deserialize from=json value="[\"x\",\"y\"]"];
:put [:serialize to=dsv value=$dict delimiter=";" order=("config")];
:put [:deserialize from=dsv value="a;b;c\n1;2;3" delimiter=";" options=dsv.plain];

# TIME & DATE
/system clock get date; ; # => e.g. Jan/01/2025
:local d [/system clock get date];
:local m [:pick $d 0 3];
:local day [:pick $d 4 6];
:local y [:pick $d 7 11];

# LOG & BEEP
:beep frequency=300 length=500ms;
/log print as-value where buffer="logParse";
:global logParseVar "";
:if ([:find [:tostr $logParseVar] "failure"] != "") do={ :put "login failure" };

# SCRIPTS & ENV
/system script run "myScript";
/environment print; 

# MERGE ARRAYS
:global arr2 ({1;2;3},5);

# CLEAR LOG
/system logging action {
   :local old [get logParse memory-lines];
   set logParse memory-lines=1;
   set logParse memory-lines=$old;
}

# BEHAVIOR & EXIT
:onerror err in={ :resolve "no-such-domain" } do={ :put "Error => $err" };
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

# RETRY COMMAND
:if ([/file print count-only where name=$ramdiskName type=disk]=0) do={
  :retry command={
    /disk add type=tmpfs tmpfs-max-size=$ramdiskMaxSize slot=$ramdiskName comment="RAM disk"
  } delay=5s max=5 on-error={
    :log error "Failed to create RAM disk";
    :error "Critical Error";
  };
};

# EXECUTE (async)
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
