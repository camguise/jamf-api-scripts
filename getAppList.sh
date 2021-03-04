#!/bin/bash

## Source External Files ##
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # parent folder of script
for resource in "${DIR}"/Resources/*.sh; do source "${resource}"; done

## Command line options/arguments ##

# Display help text to describe available command-line options
helpText () {
	echo "Usage: $(basename "$0") [options] -c /CONFIG/Path/file.cfg
	
-- Gets a list of all mobile device application names, URLs and license
   counts in a CSV format
e.g. $(basename "$0") -v -c ~/Downloads/customer.cfg  > ~/Downloads/AppList.csv
	
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

apps=$(httpGet "/JSSResource/mobiledeviceapplications")

appIDs=( $( getXPathIDsFromPath "/" "${apps}" ))

echo '"App Name","iTunes URL","Total VPP Licenses","Bundle ID","Distribution Method"'

for i in ${appIDs[@]}; do

	# Get full app details to be parsed
	appXML=$(httpGet "/JSSResource/mobiledeviceapplications/id/${i}" | xmllint --format -)
	
	# Uncomment to print out the first app in full and then exit. Used for testing
	#echo "${appXML}" | grep -v -e "<data>"; exit 1
	
	appName=$(getXPathValueFromID "/mobile_device_application" "$i" "/name" "${apps}" | iconv -f utf-8 -t ascii//translit)
	appURL=$(echo "${appXML}" | grep -e "<itunes_store_url>" | /usr/bin/perl -lne 'BEGIN{undef $/} while (/<itunes_store_url>(.*?)<\/itunes_store_url>/sg){print $1}' | awk '{ print "\""$0"\""}')
	appLicenses=$(echo "${appXML}" | grep -e "<total_vpp_licenses>" | /usr/bin/perl -lne 'BEGIN{undef $/} while (/<total_vpp_licenses>(.*?)<\/total_vpp_licenses>/sg){print $1}' | awk '{ print "\""$0"\""}')
	bundleID=$(echo "${appXML}" | grep -e "<bundle_id>" | /usr/bin/perl -lne 'BEGIN{undef $/} while (/<bundle_id>(.*?)<\/bundle_id>/sg){print $1}' | awk '{ print "\""$0"\""}')
	distributionMethod=$(echo "${appXML}" | grep -e "<deployment_type>" | /usr/bin/perl -lne 'BEGIN{undef $/} while (/<deployment_type>(.*?)<\/deployment_type>/sg){print $1}' | awk '{ print "\""$0"\""}')
	
	echo "\"${appName}\",${appURL},${appLicenses},${bundleID},${distributionMethod}"
done
