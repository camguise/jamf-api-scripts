#!/bin/bash
### Name: JamfBootstrap.sh
### Description: This script performs initial configuration for a new Jamf instance via
###   the API. This script was created for use within my organisation (Cyclone Computer
###   Company Ltd) you may need to modify it for your own environment.
### Created by: Campbell Guise - cam@guise.co.nz
### Created: 2019-02-23

COMPANY_NAME="Cyclone" # Short name of the company (should not contain spaces or symbols)

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

if [[ -z "${OUTPUT_FILE}" ]]; then
	echo "Error: You must specify an output file (-o)" >&2
	echo ""
	helpText
	exit 1
fi

! regexCheck "${COMPANY_NAME}" "^([a-z]|[A-Z]|[0-9]|-)+$" && \
	echo "Error: COMPANY_NAME must contain only lowercase letters, numbers or a hyphen" >&2 && exit 1

jamfAddress=$(getUserInputMatchingRegex "Jamf Pro server address" \
	"${JAMF_URL_REGEX}" "You must specify a valid server URL, including 'https://'")
jamfAdminUser=$(getUserInputMatchingRegex "Jamf admin username" "^([a-z]|[0-9]|-)+$" \
	"Username must contain only lowercase letters, numbers or a hyphen")
jamfAdminPassword=$(getUserInputMatchingRegex "Jamf admin password" "${REGEX_ANY}" "" true)
echo -e "\n"

jamfAdminKey=$(echo -n "${jamfAdminUser}:${jamfAdminPassword}" | base64)

JAMF_AUTH_KEY="${jamfAdminKey}"
JAMF_URL="${jamfAddress}"

testServerConnection "/JSSResource/accounts"

lowerCompanyName=$(echo "${COMPANY_NAME}" | awk '{print tolower($0)}')
jamfApiUser="${lowerCompanyName}-api"
jamfApiPassword=$(openssl rand -base64 32 | tr -cd '[a-zA-Z0-9]._-')

## Create saved mobile device Search for data export in future
xmlData="
<advanced_mobile_device_search>
  <name>${COMPANY_NAME}Export</name>
  <sort_1/>
  <sort_2/>
  <sort_3/>
  <criteria/>
  <display_fields>
    <display_field>
      <name>Display Name</name>
    </display_field>
    <display_field>
      <name>iOS Version</name>
    </display_field>
    <display_field>
      <name>Last Inventory Update</name>
    </display_field>
    <display_field>
      <name>Model</name>
    </display_field>
    <display_field>
      <name>Model Identifier</name>
    </display_field>
    <display_field>
      <name>Serial Number</name>
    </display_field>
    <display_field>
      <name>Wi-Fi MAC Address</name>
    </display_field>
    <display_field>
      <name>Building</name>
    </display_field>
    <display_field>
      <name>Department</name>
    </display_field>
  </display_fields>
</advanced_mobile_device_search>
"

if httpExists "/JSSResource/advancedmobiledevicesearches/name/${COMPANY_NAME}Export"; then
	verbose "Updating ${COMPANY_NAME}Export..."
	httpPut "/JSSResource/advancedmobiledevicesearches/name/${COMPANY_NAME}Export" "${xmlData}"
else
	verbose "Adding ${COMPANY_NAME}Export..."
	httpPost "/JSSResource/advancedmobiledevicesearches" "${xmlData}"
fi

## Create departments
departments=("Staff BYOD" "Staff School Owned" "Student 1:1" "Student BYOD" "Student Shared")

for department in "${departments[@]}"; do
	urlDepartment=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${department}")
	xmlData="<department><name>${department}</name></department>"
	if ! httpExists "/JSSResource/departments/name/${urlDepartment}"; then
		verbose "Adding ${department}..."
		httpPost "/JSSResource/departments" "${xmlData}"
	fi
done

## Create API user. Passwords can't be set via API so API password will be generated and
## printed out at the end of this script.
xmlData="
<account>
  <name>${jamfApiUser}</name>
  <directory_user>false</directory_user>
  <full_name>${COMPANY_NAME} API User</full_name>
  <email/>
  <email_address/>
  <enabled>Enabled</enabled>
  <force_password_change>false</force_password_change>
  <access_level>Full Access</access_level>
  <privilege_set>Custom</privilege_set>
  <privileges>
    <jss_objects>
      <privilege>Read Categories</privilege>
    </jss_objects>
    <jss_settings/>
    <jss_actions/>
    <recon/>
    <casper_admin/>
    <casper_remote/>
    <casper_imaging/>
  </privileges>
</account>
"

if httpExists "/JSSResource/accounts/username/${jamfApiUser}"; then
	verbose "Updating ${COMPANY_NAME} API User..."
	httpPut "/JSSResource/accounts/username/${jamfApiUser}" "${xmlData}"
else
	verbose "Adding ${COMPANY_NAME} API User..."
	httpPost "/JSSResource/accounts" "${xmlData}"
fi

createConfig "${jamfAddress}" "${jamfApiUser}" "${jamfApiPassword}"
apiUserXml=$(httpGet "/JSSResource/accounts/username/${jamfApiUser}")
apiUserID=$(getXPathValue "/account/id" "${apiUserXml}")
echo "############################ SUMMARY #################################"
echo "You need to go to the Jamf Pro server and set the password for your new API user"
echo "URL: ${JAMF_URL}/accounts.html?id=${apiUserID}&o=u"
echo "User: ${jamfApiUser}"
echo "Password: ${jamfApiPassword}"
echo "---------------------------------------------------------------------"
echo "You can then test your config file:"
echo "$ ./testConfigFile.sh -c ${OUTPUT_FILE}"
echo "#####################################################################"