#!/bin/bash

## Source External Files ##
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # parent folder of script
source "${DIR}"/Resources/globals.sh
source "${DIR}"/Resources/functions.sh
source "${DIR}"/Resources/F_XPath.sh

# App settings to be applied
# You must supply a value for each of these items
APP_autoDeploy="true" # true = Deploy Automatically; false = Self Service
APP_availableAfterInstall="false" # true = Display app in Self Service after it is installed
APP_removeOnUnenroll="true" # true = Remove app when MDM profile is removed
APP_itunesRegion="NZ" # Country code for iTunes
APP_itunesSyncHour="0" # Time of day (in minutes) to sync with iTunes each day to automatically update app description
APP_enableItunesSync="false" # Wether or not to sync information with iTunes each day
APP_forceAppUpdates="false" # Automatically Force App Updates on devices

APP_vppLicenses="true" # true = Assign VPP content for this app (if using true you must provide valid vppAccountID below)
APP_vppAccountID=1 # If you are unsure on this run the below command for a list
#$ /usr/bin/curl https://your.jamf.server.com/JSSResource/vppaccounts -u jamfadmin

## Command line options/arguments ##

# Display help text to describe available command-line options
helpText () {
	echo "Usage: $(basename "$0") [options] -c /CONFIG/Path/file.cfg -o /OUTPUT/Path/file.cfg
	
-- Set specified settings on all mobile device VPP apps
e.g. $(basename "$0") -v -c ~/Downloads/customer.cfg
	
options:
    -h                show this help text
    -o [file path]    output file for config. Can't be used with -c
    -c [file path]    input an existing config file. Can't be used with -o
    -v                verbose output
    -n                dry run without performing any operations on the server"
}

while getopts ":o:c:vnh" opt; do
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
		n)
			DRY_RUN=true
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
testServerConnection

apps=$(httpGet "/JSSResource/mobiledeviceapplications")

appCount=$(getXPathCount "/mobile_device_applications/mobile_device_application" "${apps}")

verbose "Count: ${appCount}"

if [[ appCount -eq 0 ]]; then
	echo "No apps found on server ${JAMF_URL}"
	exit 0
fi

appIDs=( $( getXPathIDsFromPath "/" "${apps}" ))

xmlData="<mobile_device_application>
	<general>
		<deploy_automatically>${APP_autoDeploy}</deploy_automatically>
		<make_available_after_install>${APP_availableAfterInstall}</make_available_after_install>
		<remove_app_when_mdm_profile_is_removed>${APP_removeOnUnenroll}</remove_app_when_mdm_profile_is_removed>
		<itunes_country_region>${APP_itunesRegion}</itunes_country_region>
    	<itunes_sync_time>${APP_itunesSyncHour}</itunes_sync_time>
    	<keep_description_and_icon_up_to_date>${APP_enableItunesSync}</keep_description_and_icon_up_to_date>
    	<keep_app_updated_on_devices>${APP_forceAppUpdates}</keep_app_updated_on_devices>
	</general>
	<vpp>
		<assign_vpp_device_based_licenses>${APP_vppLicenses}</assign_vpp_device_based_licenses>
		<vpp_admin_account_id>${APP_vppAccountID}</vpp_admin_account_id>
	</vpp>
</mobile_device_application>"



for i in ${appIDs[@]}; do
	appName=$(getXPathValueFromID "/mobile_device_application" "$i" "/name" "${apps}")
	printf "Modifying App ${appName}... "
	$DRY_RUN && echo "[Dry Run]"
	! $DRY_RUN && httpPut "/JSSResource/mobiledeviceapplications/id/${i}" "${xmlData}" && echo "[Success]"
done