#!/bin/bash

## Source External Files ##
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # parent folder of script
for resource in "${DIR}"/Resources/*.sh; do source "${resource}"; done

## Command line options/arguments ##

# Display help text to describe available command-line options
helpText () {
	echo "Usage: $(basename "$0") [options] -c /OUTPUT/Path/file.cfg
	
-- Test a Jamf Pro API config file before trying to use it with one of the scripts
e.g. $(basename "$0") -v -o ~/Downloads/customer.cfg
	
options:
    -h                show this help text
    -c [file path]    input an existing config file
    -v                verbose output"
}

while getopts ":c:vh" opt; do
	case $opt in
		c)
			CONFIG_FILE=$(realPath "$OPTARG")
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

## MAIN SCRIPT ##

loadConfig

httpDelete "/JSSResource/accounts/username/cyclone-api" | true
httpDelete "/JSSResource/advancedmobiledevicesearches/name/CycloneExport" | true