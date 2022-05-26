#!/usr/bin/env bash
JAMF_USER=$1
SEARCH_FIELD='.computer.general.serial_number'

if [[ -z "$JAMF_PASSWORD" ]]; then \
    echo "you need to: export JAMF_PASSWORD=<your Jamf password>"
    exit 1
fi
JAMF_CREDS="$JAMF_USER:$JAMF_PASSWORD"
COMPUTERS_IDFILE=/tmp/computers.$$.json
SERIALS_FILE=/tmp/serials.$$.json
/usr/bin/curl --silent --max-time 30 --request GET --write-out '%{http_code}' --header 'Accept: application/json' --header 'Content-Type: application/json' --url https://devins01.jamfcloud.com/JSSResource/computers/subset/basic -u $JAMF_CREDS | jq .computers[].id > $COMPUTERS_IDFILE
for COMPUTER_ID in `cat $COMPUTERS_IDFILE`; do \
   /usr/bin/curl --silent --max-time 30 --request GET --write-out '%{http_code}' --header 'Accept: application/json' --header 'Content-Type: application/json' --url https://devins01.jamfcloud.com/JSSResource/computers/id/$COMPUTER_ID  -u"$JAMF_CREDS" | jq $SEARCH_FIELD | sed -e's/"//g' >> $SERIALS_FILE
done;
