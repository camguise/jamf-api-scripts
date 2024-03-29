### Name: F_JamfConfig.sh
### Description: Functions which work with the configuration files used by other scripts
###   in this project.
### Created by: Campbell Guise - cam@guise.co.nz
### Created: 2019-02-17

# -------------------------------------
# Interactive prompts to allow the user to create a new config file and save to disk.
# Globals:
#   OUTPUT_FILE
# Arguments:
#   jamfAddress     - Server address for Jamf [Optional]
#   jamfApiUser     - API user account [Optional]
#   jamfApiPassword - Password for API user [Optional]
# Returns:
#   NONE
# -------------------------------------
function createConfig () {
	# local variables only, these are not used as parameters
	local jamfAddress="$1"
	local jamfApiUser="$2"
	local jamfApiPassword="$3"
	
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
	
	# Ask the user for input
	if [[ ! -z "${OUTPUT_FILE}" ]]; then
		
		[ ! -z "${jamfAddress}" ] || jamfAddress=$(getUserInputMatchingRegex "Jamf Pro server address" \
	"${JAMF_URL_REGEX}" "You must specify a valid server URL, including 'https://'")

		[ ! -z "${jamfApiUser}" ] || jamfApiUser=$(getUserInputMatchingRegex "Jamf Pro API username  " "^([a-z]|\.|[0-9]|-)+$" \
	"Username must contain only lowercase letters, numbers or a hyphen")
		[ ! -z "${jamfApiPassword}" ] || jamfApiPassword=$(getUserInputMatchingRegex "Jamf Pro API password  " "${REGEX_ANY}" "" true)
	
		jamfApiKey=$(echo -n "${jamfApiUser}:${jamfApiPassword}" | base64)
	
		echo "## Jamf API Configuration ##" > "${OUTPUT_FILE}"
		echo "JAMF_AUTH_KEY='${jamfApiKey}' # echo -n 'user:password' | base64" >> "${OUTPUT_FILE}"
		echo "JAMF_URL='${jamfAddress}' # Including port if not using 443" >> "${OUTPUT_FILE}"
		
		verbose "Config file has been written. You can now use this file in other scripts."
		verbose " -c ${OUTPUT_FILE}"
	fi
}

# -------------------------------------
# Loads the specified config file and checks that it contains the required keys
# Globals:
#   CONFIG_FILE
# Arguments:
#   NONE
# Returns:
#   NONE
# -------------------------------------
function loadConfig () {
	if [[ -z "${CONFIG_FILE}" ]]; then
		echo "Error: You must specify a config file (-c)" >&2
		exit 1
	fi
	
	if [[ ! -f "${CONFIG_FILE}" ]]; then
		echo "Error: No config file found at ${CONFIG_FILE}" >&2
		exit 1
	fi
	
	verbose "Loading config ${CONFIG_FILE}..."
	source "${CONFIG_FILE}"

	for item in ${CONFIG_REQUIRED_ITEMS[@]}; do
		if [[ -z "${!item}" ]]; then
			echo "Error: You must specify ${item} in the config file"
			exit 1
		fi
	done
	
	verbose "Config file is valid"
}

# -------------------------------------
# Tests the values supplied by the config file by making an API request.
# Scripts which use this functions should specify and endpoint which they will already
# need access to later in the script. This keeps the API user permissions to a minimum.
# Globals:
#   JAMF_URL
# Arguments:
#   testEndpoint - URI for and endpoint to use for testing
# Returns:
#   NONE
# -------------------------------------
function testServerConnection () {
	local testEndpoint="$1"
	
	# httpGet function will exit the script and display appropriate error if required
	httpGet "${testEndpoint}" > /dev/null
	
	# If there are no errors then the script will continue
	verbose "Connection to server ${JAMF_URL} was successful"
}

# -------------------------------------
# Creates a group if it doesn't exist. Otherwise updates the group to match supplied XML.
# Globals:
#   NONE
# Arguments:
#   xmlData - XML to define the group parameters
# Returns:
#   NONE
# -------------------------------------
function createUpdateGroup () {
	local xmlData="$1"
	
	local groupName=$(getXPathValue "/mobile_device_group/name" "${xmlData}")
	local encodedGroupName=$(uriEncode "${groupName}")

	if httpExists "/JSSResource/mobiledevicegroups/name/${encodedGroupName}"; then
		verbose "Updating group ${groupName}..."
		httpPut "/JSSResource/mobiledevicegroups/name/${encodedGroupName}" "${xmlData}"
	else
		verbose "Adding group ${groupName}..."
		httpPost "/JSSResource/mobiledevicegroups" "${xmlData}"
	fi
}
