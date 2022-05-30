#!/usr/bin/env bash
CURL=`which curl`
IFS=$'\n'
SERIAL_GET_PATH=/JSSResource/computers/serialnumber/

## Source External Files ##
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # parent folder of script
for resource in "${DIR}"/Resources/*.sh; do source "${resource}"; done

## Check Curl is on Path
if [[ -z "$CURL" ]]; then
    echo "curl should be on your path"
    exit 1
fi

## Command line options/arguments ##

# Display help text to describe available command-line options
helpText () {
	echo "Usage: $(basename "$0") [options] -c /OUTPUT/Path/file.cfg -i inventory.csv

-- Given a CSV with serial, query Jamf Pro API and produce a CSV which indicates which serials are JAMF managed.
e.g. $(basename "$0") -v -c ~/Downloads/customer.cfg -i /path/to/inventory.csv

options:
    -h                      show this help text
    -c [file path]          input an existing config file
    -i [inventory csv path] a csv file where each row starts with a serial 
    -v                verbose output"
}

while getopts "i:c:vh" opt; do
	case $opt in
		c)
			CONFIG_FILE=$(realPath "$OPTARG")
			;;
		i)
			INVENTORY_FILE=$(realPath "$OPTARG")
			;;
		v)
			VERBOSE=true
			;;
		h)
			helpText
			exit 0
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

## Load config
loadConfig

# Loop rows of inventory file, pull out serial and check in JAMF
for INVENTORY_ROW in `cat $INVENTORY_FILE`; do
    SERIAL=`echo $INVENTORY_ROW | cut -d, -f1 | sed -e 's/\s+//'`
    if [[ ! -z "$SERIAL" ]]; then
        if httpExists "${SERIAL_GET_PATH}/$SERIAL"; then
           echo "$INVENTORY_ROW,found"
        else
            echo "$INVENTORY_ROW,not found"
        fi
    fi
done;
