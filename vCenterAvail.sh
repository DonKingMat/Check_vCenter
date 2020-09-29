#!/bin/bash

U=administrator@fritz.box
P=vmVMvmVMvmVM!123
vcenter=10.11.12.13
SLACKCHANNEL="hetzner"
SLACKUSER="Rechenzentrum"
LAMETRIC="eschersburg"
EMOJI=":zap:"
SLACK_HOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/HOOK

START=$(date +%s)
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
		$CURL --silent -X POST --data-urlencode "payload={\"channel\": \"${LAMETRIC}\", \"username\": \"Rechenzentrum\", \"text\": \"${MELDUNG}\", \"icon_emoji\": \"${EMOJI}\"}" ${SLACK_HOOK_URL}

VMS=$(echo $VALUE | $JQ -r '.value | .[].vm')
for VM in $VMS ; do
	VMHOSTNAME=$($CURL -s -k -H  'Accept:application/json' -H "vmware-api-session-id:${KEY}" -X GET https://${vcenter}/rest/vcenter/vm/$VM/guest/networking | jq -r '.value.dns_values.host_name')
	VMNAME=$(echo $VALUE | $JQ -r '.value | .[] | select(.vm == "'${VM}'") | .name')
	VMDHCPIP="null"
	VMIP="null"
	VMDHCPIP=$($CURL -s -k -H  'Accept:application/json' -H "vmware-api-session-id:${KEY}" -X GET https://${vcenter}/rest/vcenter/vm/${VM}/guest/networking/interfaces | jq -r 'first(.value | .[].ip.ip_addresses | .[] | select(.origin != null) | select(.origin == "DHCP") | .ip_address)')
	MESSAGE="DHCP IP $VMDHCPIP"
	if [[ $VMDHCPIP != *"."*"."*"."* ]] ; then
		VMIP=$($CURL -s -k -H  'Accept:application/json' -H "vmware-api-session-id:${KEY}" -X GET https://${vcenter}/rest/vcenter/vm/$VM/guest/networking/interfaces | jq -r 'first(.value | .[].ip.ip_addresses | .[].ip_address)')
		MESSAGE="static IP $VMIP"
	fi
	
	MELDUNG="VM-Code $VM is host $VMHOSTNAME has VM name $VMNAME and $MESSAGE"
	$CURL --silent -X POST --data-urlencode "payload={\"channel\": \"${SLACKCHANNEL}\", \"username\": \"Rechenzentrum\", \"text\": \"${MELDUNG}\", \"icon_emoji\": \"${EMOJI}\"}" ${SLACK_HOOK_URL}
done

		exit
	fi
done

exit
