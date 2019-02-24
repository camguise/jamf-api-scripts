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

### Remove ###
#source ~/Downloads/cycduddev-jssadmin.cfg

## Command line options/arguments ##

# Display help text to describe available command-line options
helpText () {
	echo "Usage: $(basename "$0") [options] -o /OUTPUT/Path/file.cfg
	
-- Apply base settings to an existing Jamf Pro instance and produce a config file for future use
e.g. $(basename "$0") -v -o ~/Downloads/customer.cfg
	
options:
    -h                show this help text
    -o [file path]    output file for config
    -C [csv path]     CSV file with apps and distribution groups [Optional]
    -v                verbose output"
}

while getopts ":o:C:vh" opt; do
	case $opt in
		o)
			OUTPUT_FILE=$(realPath "$OPTARG")
			;;
		C)
			csvFile=$(realPath "$OPTARG")
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

if [[ -z "${JAMF_URL}" && -z "${JAMF_AUTH_KEY}" ]]; then
	jamfAddress=$(getUserInputMatchingRegex "Jamf Pro server address" \
		"${JAMF_URL_REGEX}" "You must specify a valid server URL, including 'https://'")
	jamfAdminUser=$(getUserInputMatchingRegex "Jamf admin username" "^([a-z]|[0-9]|-)+$" \
		"Username must contain only lowercase letters, numbers or a hyphen")
	jamfAdminPassword=$(getUserInputMatchingRegex "Jamf admin password" "${REGEX_ANY}" "" true)
	echo -e "\n"

	jamfAdminKey=$(echo -n "${jamfAdminUser}:${jamfAdminPassword}" | base64)

	JAMF_AUTH_KEY="${jamfAdminKey}"
	JAMF_URL="${jamfAddress}"
fi

lowerCompanyName=$(echo "${COMPANY_NAME}" | awk '{print tolower($0)}')
jamfApiUser="${lowerCompanyName}-api"
jamfApiPassword=$(openssl rand -base64 32 | tr -cd '[a-zA-Z0-9]._-')

testServerConnection "/JSSResource/accounts"

if [[ ! -z "${csvFile}" ]]; then
	if validateCSV "${csvFile}"; then
		IFS= read -r line < "${csvFile}"
		groupsLine=$(echo "${line}" | awk -F",%groups_start%,|,NULL,|,%groups_end%," '{ print $2; }')

		buildings=()
		echo "Found the following building from ${inputCSV}:"
		IFS=, read -ra fields <<<"${groupsLine}"
		for field in "${fields[@]}"; do
			echo " - ${field}"
			buildings+=("${field}")
		done

		echo ""
		echo "Check that these group names are correct before continuing."
		! confirmNo "Are the group names correct?" && echo "Canceling..." >&2 && exit 1

		verbose "Continuing..."
		
		for building in "${buildings[@]}"; do
			urlBuilding=$(uriEncode "${building}")
			xmlData="<building><name>${building}</name></building>"
			if ! httpExists "/JSSResource/buildings/name/${urlBuilding}"; then
				verbose "Adding building ${building}..."
				httpPost "/JSSResource/buildings" "${xmlData}"
			else
				verbose "Building ${building} already exists"
			fi
		done
	else
		exit 1
	fi
fi

## Create saved mobile device Search for data export in future
xmlData="
<advanced_mobile_device_search>
  <name>${COMPANY_NAME} Export</name>
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
urlSearchName=$(uriEncode "${COMPANY_NAME} Export")
if httpExists "/JSSResource/advancedmobiledevicesearches/name/${urlSearchName}"; then
	verbose "Updating ${COMPANY_NAME} Export..."
	httpPut "/JSSResource/advancedmobiledevicesearches/name/${urlSearchName}" "${xmlData}"
else
	verbose "Adding ${COMPANY_NAME} Export..."
	httpPost "/JSSResource/advancedmobiledevicesearches" "${xmlData}"
fi

## Create Departments
departments=("Staff BYOD" "Staff School Owned" "Student 1:1" "Student BYOD" "Student Shared")

for department in "${departments[@]}"; do
	urlDepartment=$(uriEncode "${department}")
	xmlData="<department><name>${department}</name></department>"
	if ! httpExists "/JSSResource/departments/name/${urlDepartment}"; then
		verbose "Adding ${department}..."
		httpPost "/JSSResource/departments" "${xmlData}"
	fi
done

## Create Groups

xmlData="
<mobile_device_group>
  <name>Pre-Stage Devices</name>
  <is_smart>true</is_smart>
  <criteria>
    <criterion>
      <name>Building</name>
      <priority>0</priority>
      <and_or>and</and_or>
      <search_type>does not match regex</search_type>
      <value>.+</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
    <criterion>
      <name>Department</name>
      <priority>1</priority>
      <and_or>or</and_or>
      <search_type>does not match regex</search_type>
      <value>.+</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
</mobile_device_group>
"
createUpdateGroup "${xmlData}"

xmlData="
<mobile_device_group>
  <name>All Managed iPads</name>
  <is_smart>true</is_smart>
  <criteria>
    <criterion>
      <name>Model</name>
      <priority>0</priority>
      <and_or>AND</and_or>
      <search_type>like</search_type>
      <value>iPad</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
    <criterion>
      <name>Mobile Device Group</name>
      <priority>1</priority>
      <and_or>and</and_or>
      <search_type>not member of</search_type>
      <value>Pre-Stage Devices</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
</mobile_device_group>
"
createUpdateGroup "${xmlData}"

xmlData="
<mobile_device_group>
  <name>All Managed Apple TVs</name>
  <is_smart>true</is_smart>
  <criteria>
    <criterion>
      <name>Model</name>
      <priority>0</priority>
      <and_or>AND</and_or>
      <search_type>like</search_type>
      <value>TV</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
    <criterion>
      <name>Mobile Device Group</name>
      <priority>1</priority>
      <and_or>and</and_or>
      <search_type>not member of</search_type>
      <value>Pre-Stage Devices</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
</mobile_device_group>
"
createUpdateGroup "${xmlData}"

xmlData="
<mobile_device_group>
  <name>All Managed iPhones</name>
  <is_smart>true</is_smart>
  <criteria>
    <criterion>
      <name>Model</name>
      <priority>0</priority>
      <and_or>AND</and_or>
      <search_type>like</search_type>
      <value>iPhone</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
    <criterion>
      <name>Mobile Device Group</name>
      <priority>1</priority>
      <and_or>and</and_or>
      <search_type>not member of</search_type>
      <value>Pre-Stage Devices</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
</mobile_device_group>
"
createUpdateGroup "${xmlData}"

xmlData="
<mobile_device_group>
  <name>All Managed iPod touches</name>
  <is_smart>true</is_smart>
  <criteria>
    <criterion>
      <name>Model</name>
      <priority>0</priority>
      <and_or>AND</and_or>
      <search_type>like</search_type>
      <value>iPod touch</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
    <criterion>
      <name>Mobile Device Group</name>
      <priority>1</priority>
      <and_or>and</and_or>
      <search_type>not member of</search_type>
      <value>Pre-Stage Devices</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
</mobile_device_group>
"
createUpdateGroup "${xmlData}"

xmlData="
<mobile_device_group>
  <name>All Staff Devices</name>
  <is_smart>true</is_smart>
  <criteria>
    <criterion>
      <name>Department</name>
      <priority>0</priority>
      <and_or>AND</and_or>
      <search_type>like</search_type>
      <value>Staff</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
</mobile_device_group>
"
createUpdateGroup "${xmlData}"

xmlData="
<mobile_device_group>
  <name>All Student Devices</name>
  <is_smart>true</is_smart>
  <criteria>
    <criterion>
      <name>Department</name>
      <priority>0</priority>
      <and_or>AND</and_or>
      <search_type>like</search_type>
      <value>Student</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
</mobile_device_group>
"
createUpdateGroup "${xmlData}"

xmlData="
<mobile_device_group>
  <name>Home Screen Wallpaper</name>
  <is_smart>true</is_smart>
  <criteria>
    <criterion>
      <name>Mobile Device Group</name>
      <priority>0</priority>
      <and_or>AND</and_or>
      <search_type>member of</search_type>
      <value>All Managed iPads</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
</mobile_device_group>
"
createUpdateGroup "${xmlData}"

xmlData="
<mobile_device_group>
  <name>Lock Screen Wallpaper</name>
  <is_smart>true</is_smart>
  <criteria>
    <criterion>
      <name>Mobile Device Group</name>
      <priority>0</priority>
      <and_or>AND</and_or>
      <search_type>member of</search_type>
      <value>All Managed iPads</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
</mobile_device_group>
"
createUpdateGroup "${xmlData}"

## Create configuration profiles
custName="Cyclone School"
custPhone="0508 4 ENABLE"
custEmail="support@cyclone.co.nz"

xmlData='
<configuration_profile>
  <general>
    <name>Lock Screen Message - All Devices</name>
    <description/>
    <uuid>512BF1E1-62BD-4739-8F40-078048D9099F</uuid>
    <deployment_method>Install Automatically</deployment_method>
    <redeploy_on_update>Newly Assigned</redeploy_on_update>
    <redeploy_days_before_certificate_expires>0</redeploy_days_before_certificate_expires>
    <payloads>&lt;?xml version="1.0" encoding="UTF-8"?&gt;&lt;!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"&gt;
&lt;plist version="1"&gt;&lt;dict&gt;&lt;key&gt;PayloadUUID&lt;/key&gt;&lt;string&gt;512BF1E1-62BD-4739-8F40-078048D9099F&lt;/string&gt;&lt;key&gt;PayloadType&lt;/key&gt;&lt;string&gt;Configuration&lt;/string&gt;&lt;key&gt;PayloadOrganization&lt;/key&gt;&lt;string&gt;Maraetai Beach School&lt;/string&gt;&lt;key&gt;PayloadIdentifier&lt;/key&gt;&lt;string&gt;512BF1E1-62BD-4739-8F40-078048D9099F&lt;/string&gt;&lt;key&gt;PayloadDisplayName&lt;/key&gt;&lt;string&gt;Lock Screen Message - All Devices&lt;/string&gt;&lt;key&gt;PayloadDescription&lt;/key&gt;&lt;string/&gt;&lt;key&gt;PayloadVersion&lt;/key&gt;&lt;integer&gt;1&lt;/integer&gt;&lt;key&gt;PayloadEnabled&lt;/key&gt;&lt;true/&gt;&lt;key&gt;PayloadRemovalDisallowed&lt;/key&gt;&lt;true/&gt;&lt;key&gt;PayloadContent&lt;/key&gt;&lt;array&gt;&lt;dict&gt;&lt;key&gt;PayloadUUID&lt;/key&gt;&lt;string&gt;A562C817-225D-4456-81F7-A3A97E1DF614&lt;/string&gt;&lt;key&gt;PayloadType&lt;/key&gt;&lt;string&gt;com.apple.shareddeviceconfiguration&lt;/string&gt;&lt;key&gt;PayloadOrganization&lt;/key&gt;&lt;string&gt;Maraetai Beach School&lt;/string&gt;&lt;key&gt;PayloadIdentifier&lt;/key&gt;&lt;string&gt;A562C817-225D-4456-81F7-A3A97E1DF614&lt;/string&gt;&lt;key&gt;PayloadDisplayName&lt;/key&gt;&lt;string&gt;com.apple.shareddeviceconfiguration&lt;/string&gt;&lt;key&gt;PayloadDescription&lt;/key&gt;&lt;string/&gt;&lt;key&gt;PayloadVersion&lt;/key&gt;&lt;integer&gt;1&lt;/integer&gt;&lt;key&gt;PayloadEnabled&lt;/key&gt;&lt;true/&gt;&lt;key&gt;IfLostReturnToMessage&lt;/key&gt;&lt;string&gt;If lost please contact '"${custName}"' - P: '"${custPhone}"' E: '"${custEmail}"' - $DEVICENAME&lt;/string&gt;&lt;/dict&gt;&lt;/array&gt;&lt;/dict&gt;&lt;/plist&gt;</payloads>
  </general>
  <scope>
    <all_mobile_devices>false</all_mobile_devices>
    <all_jss_users>false</all_jss_users>
    <mobile_devices/>
    <buildings/>
    <departments/>
    <mobile_device_groups>
      <mobile_device_group>
        <name>All Managed iPads</name>
      </mobile_device_group>
    </mobile_device_groups>
    <jss_users/>
    <jss_user_groups/>
    <limitations>
      <users/>
      <user_groups/>
      <network_segments/>
      <ibeacons/>
    </limitations>
    <exclusions>
      <mobile_devices/>
      <buildings/>
      <departments/>
      <mobile_device_groups>
        <mobile_device_group>
          <name>Pre-Stage Devices</name>
        </mobile_device_group>
      </mobile_device_groups>
      <users/>
      <user_groups/>
      <network_segments/>
      <ibeacons/>
      <jss_users/>
      <jss_user_groups/>
    </exclusions>
  </scope>
  <self_service>
    <self_service_description/>
    <security>
      <removal_disallowed>Never</removal_disallowed>
    </security>
    <self_service_icon/>
    <feature_on_main_page>false</feature_on_main_page>
    <self_service_categories/>
  </self_service>
</configuration_profile>
'
profileName=$(getXPathValue "/configuration_profile/general/name" "${xmlData}")
urlProfileName=$(uriEncode "${profileName}")

if ! httpExists "/JSSResource/mobiledeviceconfigurationprofiles/name/${urlProfileName}"; then
	verbose "Adding profile ${profileName}..."
	httpPost "/JSSResource/mobiledeviceconfigurationprofiles" "${xmlData}"
else
	verbose "Profile ${profileName} already exists"
fi

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
      <privilege>Read Mobile Device Applications</privilege>
      <privilege>Update Mobile Device Applications</privilege>
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