#!/bin/bash
### Name: JamfBootstrap.sh
### Description: This script performs initial configuration for a new Jamf instance via
###   the API. This script was created for use within my organisation (Cyclone Computer
###   Company Ltd) you may need to modify it for your own environment.
### Created by: Campbell Guise - cam@guise.co.nz
### Updated: 2019-02-23

COMPANY_NAME="cyclone" # Used to create api user

## Source External Files ##
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # parent folder of script
for resource in "${DIR}"/Resources/*.sh; do source "${resource}"; done

## Command line options/arguments ##

# Display help text to describe available command-line options
helpText () {
	echo "Usage: $(basename "$0") [options] -o /OUTPUT/Path/file.cfg
	
-- Apply base settings to an existing Jamf Pro instance and produce a config file for future use
e.g. $(basename "$0") -v -o ~/Downloads/customer.cfg
	
options:
    -h                show this help text
    -o [file path]    output file for config
    -v                verbose output"
}

while getopts ":o:vh" opt; do
	case $opt in
		o)
			OUTPUT_FILE=$(realPath "$OPTARG")
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

# TO-DO: make this into a function
jamfAddress=''
requestString='the Jamf Pro server address'
regexTest="${JAMF_URL_REGEX}"
regexError="You must specify a valid server URL, including 'https://'"
while [[ -z $jamfAddress ]]; do
	read -p "Enter ${requestString} : " tempAddress
	[[ -z "${tempAddress}" ]] && echo "Error: You must specify ${requestString}" >&2 && continue
	! regexCheck "${tempAddress}" "${regexTest}" && echo "Error: ${regexError}" >&2 && continue
	
	jamfAddress=${tempAddress}
done

# Ask the user for a Jamf admin account
# echo "Please provide your Jamf Pro Server admin credentials"
# echo "These credentials will not be saved anywhere they are only used to create the base setup including a new API user with limited permissions"
# read -p "Enter the Jamf Pro server address : " jamfAddress
# read -p "Enter your admin username         : " jamfAdminUser
# read -p "Enter your admin user password    : " -s jamfAdminPassword
# echo -e "\n"
# 
# jamfAdminKey=$(echo -n "${jamfApiUser}:${jamfApiPassword}" | base64)
# 
# JAMF_AUTH_KEY="${jamfAdminKey}"
# JAMF_URL="${jamfAddress}"
# 
# jamfApiUser="${COMPANY_NAME}-api"
# jamfApiPassword=$(openssl rand -base64 32 | tr -cd '[a-zA-Z0-9]._-')
# 
# createConfig "${jamfAddress}" "${jamfApiUser}" "${jamfApiPassword}"