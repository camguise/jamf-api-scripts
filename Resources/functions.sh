# Relies on globals.sh being sourced before this file.

function httpStatusCheck {
	local httpMethod=$1
	local httpCode=$2
	local uriPath=$3
	local returnData=$4
	
	local error503='[{"healthCode":2,"httpCode":503,"description":"SetupAssistant"}]
'
	
	if [[ ${httpCode} -ne 200 && ${httpCode} -ne 201 ]]; then
		echo "Status: $httpCode" >&2
		echo "Command: http ${httpMethod} ${JAMF_URL}/${uriPath}" >&2
	fi
	
	if [[ ${httpCode} -eq 200 || ${httpCode} -eq 201 ]]; then
		echo "" > /dev/null
	elif [ ${httpCode} -eq 000 ]; then
		echo "Could not resolve host or connection timeout: ${JAMF_URL}" >&2
		exit 1
	elif [ ${httpCode} -eq 401 ]; then
		echo "The authentication provided is invalid or you do not have permission to the requested resource" >&2
		exit 1
	elif [ ${httpCode} -eq 403 ]; then
		echo "The authentication provided is does not have permission to the requested resource" >&2
		exit 1
	elif [ ${httpCode} -eq 404 ]; then
		echo "The requested resource was not found (404): ${JAMF_URL}/${uriPath}" >&2
		exit 1
	elif [[ ${httpCode} -eq 503 && "${returnData}" == "${error503}" ]]; then
		echo "The Jamf API is not finished being provisioned yet for this server: ${JAMF_URL}" >&2
		exit 1
	elif [ ${httpCode} -eq 500 ]; then
		echo "The requested failed due to an internal server error. Check your configuration and try again." >&2
		echo "${returnData}" >&2
		exit 1
	else
		echo "Curl operation/command failed due to server return code - ${httpCode}" >&2
		echo "${returnData}" >&2
		exit 2
	fi
}

# Make sure to pass the full path including "/JSSResource"
function httpGet {
	local uriPath=$1
	
	local returnCode=0
	local result=$( \
	/usr/bin/curl \
		--silent \
		--max-time ${CONNECTION_MAX_TIMEOUT} \
		--request GET \
		--write-out "%{http_code}" \
		--header "${HEADER_ACCEPT}" \
		--header "${HEADER_CONTENT_TYPE}" \
		--url ${JAMF_URL}/${uriPath} \
		--header "Authorization: Basic ${JAMF_AUTH_KEY}" \
		|| returnCode=$? )
		
	local resultStatus=${result: -3}
	local resultXML=${result%???}
	
	if [ ${returnCode} -eq 0 ]; then
		httpStatusCheck "GET" "${resultStatus}" "${uriPath}" "${resultXML}"
	else
		echo "Curl connection failed with unknown return code ${returnCode}" >&2
		exit 3
	fi
	
	echo "${resultXML}"
}

# Make sure to pass the full path including "/JSSResource"
function httpPut {
	local uriPath=$1
	local xmlData=$2
	
	local returnCode=0
	local result=$( \
	/usr/bin/curl \
		--silent \
		--request PUT \
		--write-out "%{http_code}" \
		--header "${HEADER_ACCEPT}" \
		--header "${HEADER_CONTENT_TYPE}" \
		--url ${JAMF_URL}/${uriPath} \
		--data "${xmlData}" \
		--header "Authorization: Basic ${JAMF_AUTH_KEY}" \
		|| returnCode=$? )
	
	local resultStatus=${result: -3}
	local resultXML=${result%???}
	
	if [ ${returnCode} -eq 0 ]; then
		httpStatusCheck "PUT" "${resultStatus}" "${uriPath}" "${resultXML}"
	else
		echo "Curl connection failed with unknown return code ${returnCode}" >&2
		exit 3
	fi
}

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