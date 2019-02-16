#!/bin/bash

# Relies on globals.sh being sourced before this file.

# Gets the real path to a file
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

# Echo out the text only if the verbose flag is set
verbose () {
	if $VERBOSE; then
        echo "$@"
    fi
}

# Ask for confirmation before performing a command. Defaults to YES
# confirm "Would you really like to execute?" && command
# Alternatively it can be used in an if statement to determine if multiple commands get run.
# if confirm "Would you like to run these commands"; then
confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure?} [Y/n] " response
    case "$response" in
        [nN][oO]|[nN]) 
            false
            ;;
        *)
            true
            ;;
    esac
}

# get number of rows returned by XPath expression
function getXPathCount {
    local xPath="count($1)"
    local data=$2
    echo "${data}" | xmllint --xpath $xPath -
}

# get string value of node returned by XPath expression
function getXPathValue {
    local xPath="string($1)"
    local data=$2
    echo "${data}" | xmllint --xpath $xPath -
}

# get another value relative to the same level as the specified id
function getXPathValueFromID {
	local searchPath="$1"
    local itemID="$2"
    local returnValue="$3"
    local data="$4"
    
    echo "${data}" | xmllint --xpath "string(/${searchPath}[id[text()='$itemID']]/${returnValue})" -
}

# get another value relative to the same level as the specified id
function getXPathIDsFromPath {
	local xPath="$1"
	local data="$2"
	
	echo "${data}" | /usr/bin/xpath "${xPath}" 2> /dev/null \
	| /usr/bin/perl -lne 'BEGIN{undef $/} while (/<id>(.*?)<\/id>/sg){print $1}'
}

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
		echo "The authentication provided is invalid" >&2
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
	local jssaddress=""
	local jssadminuser=""
	local jssadminpwd=""
	
	if [[ -f "${OUTPUT_FILE}" ]]; then
		echo "The output file you have specified already exists." >&2
		echo "${OUTPUT_FILE}"
		! confirm "Would you like to overwrite it?" && exit 1
	fi

	if [[ ! -z "${OUTPUT_FILE}" ]]; then
		read -p "Enter the JSS server address  : " jssaddress
		read -p "Enter your JSS admin username : " jssadminuser
		read -p "Enter your JSS admin password : " -s jssadminpwd
		echo -e "\n"
	
		jsskey=$(echo -n "${jssadminuser}:${jssadminpwd}" | base64)
	
		echo "## Jamf API Configuration ##" > "${OUTPUT_FILE}"
		echo "JAMF_AUTH_KEY='${jsskey}' # echo -n 'user:password' | base64" >> "${OUTPUT_FILE}"
		echo "JAMF_URL='${jssaddress}' # Including port if not using 443" >> "${OUTPUT_FILE}"
		CONFIG_FILE="${OUTPUT_FILE}"
		verbose "Config file written:"
		verbose "--------------------------------------------"
		$VERBOSE && cat "${CONFIG_FILE}"
		verbose "--------------------------------------------"
	fi
}

function loadConfig {
	if [[ -z "${OUTPUT_FILE}" && -z "${CONFIG_FILE}" ]]; then
		echo "Error: You must specify either a output file (-o) or config file (-c)" >&2
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

	if [[ ! -z "${CONFIG_FILE}" && ! -f "${CONFIG_FILE}" ]]; then
		echo "Error: No config file found at ${CONFIG_FILE}" >&2
		exit 1
	fi

	if [[ ! -z "${OUTPUT_FILE}" ]]; then
		createConfig
	fi

	verbose "Loading config ${CONFIG_FILE}..."
	source "${CONFIG_FILE}"
	
	for item in ${CONFIG_REQUIRED_ITEMS[@]}; do
		if [[ -z "${!item}" ]]; then
			echo "Error: You must specify ${item} in the config file"
			exit 1
		fi
	done
}