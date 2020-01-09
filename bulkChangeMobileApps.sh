#!/bin/bash

## USER VARIABLES ##
# You can choose to set any of the variables below to apply to mobile device apps in bulk.
# If you don't wish to modify that setting from the existing value in Jamf Pro leave the
# value blank. These variables can be overridden by specifying them inside your config file.

# true  = Deploy Automatically
# false = Self Service
APP_autoDeploy=""

# true = Display app in Self Service after it is installed
APP_availableAfterInstall=""

# Country code for iTunes (two letter country code)
APP_itunesRegion=""

# Time of day (in seconds) to sync with iTunes each day to automatically update app description
# E.g. 2:34pm = 14:34 hrs = 14x60x60 (50,400) + 34x60 (2,040) = 52,440 seconds
APP_itunesSyncHour=""

# true = Schedule Jamf Pro to automatically check iTunes for app updates
APP_enableItunesSync=""

# true = Automatically Force App Updates
APP_forceAppUpdates=""

# true = Make app managed when possible
APP_makeManaged=""

# true = Make app managed if currently installed as unmanaged 
APP_takeOverAsManaged=""

# true = Remove app when MDM profile is removed
APP_removeOnUnenroll=""

# true = Prevent backup of app data
APP_preventBackup=""

# true = Assign VPP content for this app
# NOTE: If using true you must provide valid vppAccountID below
APP_vppLicenses=""

# If you are unsure on this run the below command for a list
# /usr/bin/curl https://your.jamf.server.com/JSSResource/vppaccounts -u jamfadmin
APP_vppAccountID=""

## DO NOT MODIFY BELOW THIS POINT ##

## Source External Files ##
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # parent folder of script
for resource in "${DIR}"/Resources/*.sh; do source "${resource}"; done

declare -a includeBundles
declare -a excludeBundles

## Command line options/arguments ##

# Display help text to describe available command-line options
helpText () {
	echo "Usage: $(basename "$0") [options] -c /CONFIG/Path/file.cfg
	
-- Set specified settings on all mobile device apps
e.g. $(basename "$0") -v -c ~/Downloads/customer.cfg
	
options:
    -h                show this help text
    -c [file path]    input an existing config file
    -v                verbose output
    -n                dry run without performing any operations on the server
    -I [file path]    include ONLY apps with bundle IDs contained in the include file
    -E [file path]    exclude bundle IDs contained in the exclude file from mass changes"
}

while getopts ":c:I:E:vnh" opt; do
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
		n)
			DRY_RUN=true
			;;
		I)
			if [[ ! -f "${OPTARG}" ]]; then
				echo "Error: No include file found at ${OPTARG}" >&2
				exit 1
			fi
			while read -r line; do includeBundles+=( "$line" ); done < "${OPTARG}"
			;;
		E)
			if [[ ! -f "${OPTARG}" ]]; then
				echo "Error: No exclude file found at ${OPTARG}" >&2
				exit 1
			fi
			while read -r line; do excludeBundles+=( "$line" ); done < "${OPTARG}"
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
testServerConnection "/JSSResource/mobiledeviceapplications"

apps=$(httpGet "/JSSResource/mobiledeviceapplications")

appCount=$(getXPathCount "/mobile_device_applications/mobile_device_application" "${apps}")

verbose "Count:     ${appCount}"
[[ "${#includeBundles[@]}" -eq 0 ]] && verbose "Include:   ALL" || verbose "Include:   ${#includeBundles[@]}"
verbose "Exclude:   ${#excludeBundles[@]}"

if [[ appCount -eq 0 ]]; then
	echo "No apps found on server ${JAMF_URL}"
	exit 0
fi

appIDs=( $( getXPathIDsFromPath "/" "${apps}" ))

xmlData="<mobile_device_application>"
xmlData="${xmlData}<general>"

[ ! -z "${APP_autoDeploy}" ] && [[ "${APP_autoDeploy}" =~ ^(true|false)$ ]] && \
	xmlData="${xmlData}<deploy_automatically>${APP_autoDeploy}</deploy_automatically>"
	
[ ! -z "${APP_availableAfterInstall}" ] && [[ "${APP_availableAfterInstall}" =~ ^(true|false)$ ]] && \
	xmlData="${xmlData}<make_available_after_install>${APP_availableAfterInstall}</make_available_after_install>"
	
[ ! -z "${APP_itunesRegion}" ] && \
	xmlData="${xmlData}<itunes_country_region>${APP_itunesRegion}</itunes_country_region>"
	
[ ! -z "${APP_itunesSyncHour}" ] && [[ "${APP_itunesSyncHour}" =~ ^[0-9]+$ ]] && [ "${APP_itunesSyncHour}" -ge 0 -a "${APP_itunesSyncHour}" -le 86340 ] && \
	xmlData="${xmlData}<itunes_sync_time>${APP_itunesSyncHour}</itunes_sync_time>"
	
[ ! -z "${APP_enableItunesSync}" ] && [[ "${APP_enableItunesSync}" =~ ^(true|false)$ ]] && \
	xmlData="${xmlData}<keep_description_and_icon_up_to_date>${APP_enableItunesSync}</keep_description_and_icon_up_to_date>"
	
[ ! -z "${APP_forceAppUpdates}" ] && [[ "${APP_forceAppUpdates}" =~ ^(true|false)$ ]] && \
	xmlData="${xmlData}<keep_app_updated_on_devices>${APP_forceAppUpdates}</keep_app_updated_on_devices>"

[ ! -z "${APP_makeManaged}" ] && [[ "${APP_makeManaged}" =~ ^(true|false)$ ]] && \
	xmlData="${xmlData}<deploy_as_managed_app>${APP_makeManaged}</deploy_as_managed_app>"
	
[ ! -z "${APP_takeOverAsManaged}" ] && [[ "${APP_takeOverAsManaged}" =~ ^(true|false)$ ]] && \
	xmlData="${xmlData}<take_over_management>${APP_takeOverAsManaged}</take_over_management>"

[ ! -z "${APP_removeOnUnenroll}" ] && [[ "${APP_removeOnUnenroll}" =~ ^(true|false)$ ]] && \
	xmlData="${xmlData}<remove_app_when_mdm_profile_is_removed>${APP_removeOnUnenroll}</remove_app_when_mdm_profile_is_removed>"

[ ! -z "${APP_preventBackup}" ] && [[ "${APP_preventBackup}" =~ ^(true|false)$ ]] && \
	xmlData="${xmlData}<prevent_backup_of_app_data>${APP_preventBackup}</prevent_backup_of_app_data>"

xmlData="${xmlData}</general>"

[ ! -z "${APP_vppLicenses}" ] && [ ! -z "${APP_vppAccountID}" ] && \
	[[ "${APP_vppLicenses}" =~ ^(true)$ ]] && [[ "${APP_vppAccountID}" =~ ^[0-9]+$ ]] && \
	xmlData="${xmlData}<vpp><assign_vpp_device_based_licenses>${APP_vppLicenses}</assign_vpp_device_based_licenses><vpp_admin_account_id>${APP_vppAccountID}</vpp_admin_account_id></vpp>"

xmlData="${xmlData}</mobile_device_application>"

if [[ "${xmlData}" == "<mobile_device_application><general></general></mobile_device_application>" ]]; then
	echo "Error: You have not specified any valid values for the USER VARIABLES" >&2
	echo "       Please update the variables and try again" >&2
	exit 1
fi

verbose "Modifying Apps:"
for i in ${appIDs[@]}; do
	appName=$(getXPathValueFromID "/mobile_device_application" "$i" "/name" "${apps}" | iconv -f utf-8 -t ascii//translit)
	appBundleID=$(getXPathValueFromID "/mobile_device_application" "$i" "/bundle_id" "${apps}" | iconv -f utf-8 -t ascii//translit)
	
	if [[ "${#includeBundles[@]}" -ne 0 ]] && arrayContains "${appBundleID}" "${includeBundles[@]}" || [[ "${#includeBundles[@]}" -eq 0 ]]; then
		if arrayContains "${appBundleID}" "${excludeBundles[@]}"; then
			$VERBOSE && printf "%-40.40s " "${appName}........................................................................."
			$VERBOSE && echo "[Exclude]"
			continue
		fi
		printf "%-40.40s " "${appName}........................................................................."
		$DRY_RUN && echo "[Dry Run]"
		! $DRY_RUN && httpPut "/JSSResource/mobiledeviceapplications/id/${i}" "${xmlData}" && echo "[Success]"
	fi
done