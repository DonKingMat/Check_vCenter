#!/bin/bash

U=administrator@fritz.box
P=vmVMvmVMvmVM!123
vcenter=10.11.12.134
START=$(date +%s)

SLACKCHANNEL="hetzner"
LAMETRIC="eschersburg"
EMOJI=":zap:"

CURL=`which curl`
JQ=`which jq`

authenticate() {

	KEY=$($CURL -s -k -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' --header 'vmware-use-header-authn: test' --header 'vmware-api-session-id: null' -u "${U}:${P}" "https://${vcenter}/rest/com/vmware/cis/session" | $JQ -r '.value')

}

inventory() {

	VALUE=$($CURL -s -k -H  'Accept:application/json' -H "vmware-api-session-id:${KEY}" -X GET https://${vcenter}/rest/vcenter/vm)

}

until [ $(echo $KEY | wc -c) -eq 33 ] ; do
	sleep 5
	authenticate
	LOOP=$(( $(date +%s) - START ))
	echo "# --- KEY Durchlauf Sekunde $LOOP"
done

# until [ "$()"  ]

while true ; do
	sleep 5
	inventory
	LOOP=$(( $(date +%s) - START ))
	echo "# --- AUTH Durchlauf Sekunde $LOOP"
	echo $VALUE
	POWER=$(echo $VALUE | $JQ -r '.value | .[] | .power_state' | grep POWERED_ON | wc -l)
	if [ $POWER -gt 1 ] ; then
		MELDUNG="Es sind $POWER Server an ($(( $(date +%s) - START ))s)"
		echo $MELDUNG
		$CURL --silent -X POST --data-urlencode "payload={\"channel\": \"${SLACKCHANNEL}\", \"username\": \"Rechenzentrum\", \"text\": \"${MELDUNG}\", \"icon_emoji\": \"${EMOJI}\"}" https://hooks.slack.com/services/T2YDLRT39/B5YFKREG0/8NEKJDxkPE1XXX
		$CURL --silent -X POST --data-urlencode "payload={\"channel\": \"${LAMETRIC}\", \"username\": \"Rechenzentrum\", \"text\": \"${MELDUNG}\", \"icon_emoji\": \"${EMOJI}\"}" https://hooks.slack.com/services/T2YDLRT39/B5YFKREG0/8NEKJDxkPE1XXX
		exit
	fi
done

exit
