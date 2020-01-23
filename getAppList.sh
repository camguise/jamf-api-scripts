#!/bin/bash

## Source External Files ##
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # parent folder of script
for resource in "${DIR}"/Resources/*.sh; do source "${resource}"; done

## Command line options/arguments ##

# Display help text to describe available command-line options
helpText () {
	echo "Usage: $(basename "$0") [options] -c /CONFIG/Path/file.cfg -o /OUTPUT/Path/file.csv
	
-- Gets a list of all mobile device application names, URLs and license
   counts in a CSV format
e.g. $(basename "$0") -v -c ~/Downloads/customer.cfg  -o ~/Downloads/AppList.csv
	
options:
    -h                show this help text
    -c [file path]    input an existing config file
    -o [file path]    output file for CSV
    -v                verbose output"
}

while getopts ":c:o:vh" opt; do
	case $opt in
		o)
			OUTPUT_FILE=$(realPath "$OPTARG")
			;;
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

if [[ -z "${OUTPUT_FILE}" ]]; then
	echo "Error: You must specify an output file (-o)" >&2
	echo ""
	helpText
	exit 1
fi

if [[ -f "${OUTPUT_FILE}" ]]; then
	echo "The output file you have specified already exists." >&2
	echo "${OUTPUT_FILE}"
	! confirmYes "Would you like to overwrite it?" && exit 1
fi

loadConfig

apps=$(httpGet "/JSSResource/mobiledeviceapplications")

appIDs=( $( getXPathIDsFromPath "/" "${apps}" ))

echo '"App Name","iTunes URL","Total VPP Licenses"' > "${OUTPUT_FILE}"

for i in ${appIDs[@]}; do
	appName=$(getXPathValueFromID "/mobile_device_application" "$i" "/name" "${apps}" | iconv -f utf-8 -t ascii//translit)
	appURL=$(httpGet "/JSSResource/mobiledeviceapplications/id/${i}" | xmllint --format - | grep -e "<itunes_store_url>" | /usr/bin/perl -lne 'BEGIN{undef $/} while (/<itunes_store_url>(.*?)<\/itunes_store_url>/sg){print $1}' | awk '{ print "\""$0"\""}')
	appLicenses=$(httpGet "/JSSResource/mobiledeviceapplications/id/${i}" | xmllint --format - | grep -e "<total_vpp_licenses>" | /usr/bin/perl -lne 'BEGIN{undef $/} while (/<total_vpp_licenses>(.*?)<\/total_vpp_licenses>/sg){print $1}' | awk '{ print "\""$0"\""}')

	echo "\"${appName}\",${appURL},${appLicenses}" >> "${OUTPUT_FILE}"
done

verbose "CSV file has been written to ${OUTPUT_FILE}"