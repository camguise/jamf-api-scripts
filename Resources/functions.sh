function createConfig {
	local jamfAddress=""
	local jamfApiUser=""
	local jamfApiPassword=""
	
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

	if [[ ! -z "${OUTPUT_FILE}" ]]; then
		read -p "Enter the Jamf Pro server address : " jamfAddress
		read -p "Enter your API username           : " jamfApiUser
		read -p "Enter your API user password      : " -s jamfApiPassword
		echo -e "\n"
	
		jamfApiKey=$(echo -n "${jamfApiUser}:${jamfApiPassword}" | base64)
	
		echo "## Jamf API Configuration ##" > "${OUTPUT_FILE}"
		echo "JAMF_AUTH_KEY='${jamfApiKey}' # echo -n 'user:password' | base64" >> "${OUTPUT_FILE}"
		echo "JAMF_URL='${jamfAddress}' # Including port if not using 443" >> "${OUTPUT_FILE}"
		CONFIG_FILE="${OUTPUT_FILE}"
		verbose "Config file has been written. You can now use this file in other scripts."
		verbose " -c ${CONFIG_FILE}"
	fi
}

function testConfig {
	if [[ -z "${CONFIG_FILE}" ]]; then
		echo "Error: You must specify a config file (-c)" >&2
		exit 1
	fi
	
	if [[ ! -f "${CONFIG_FILE}" ]]; then
		echo "Error: No config file found at ${CONFIG_FILE}" >&2
		exit 1
	fi
	
	source "${CONFIG_FILE}"

	for item in ${CONFIG_REQUIRED_ITEMS[@]}; do
		if [[ -z "${!item}" ]]; then
			echo "Error: You must specify ${item} in the config file"
			exit 1
		fi
	done
	
	verbose "Config file is valid"
}

function testServerConnection {
	httpGet "/JSSResource/buildings" > /dev/null
	
	verbose "Connection to server ${JAMF_URL} was successful"
}

function loadConfig {
	if [[ -z "${OUTPUT_FILE}" && -z "${CONFIG_FILE}" ]]; then
		echo "Error: You must specify either an output file (-o) or config file (-c)" >&2
		echo ""
		helpText
		exit 1
	fi

	if [[ ! -z "${CONFIG_FILE}" && ! -z "${OUTPUT_FILE}" ]]; then
		echo "Error: You can't specify both a config file and an output file" >&2
		echo ""
		helpText
		exit 1
	fi

	if [[ ! -z "${OUTPUT_FILE}" ]]; then
		createConfig
	fi

	verbose "Loading config ${CONFIG_FILE}..."
	
	testConfig
}