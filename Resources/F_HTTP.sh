### Name: F_HTTP.sh
### Description: Wrapper functions for cURL commands to perform error checking and allow
###   the scripts to make simplified function calls. These HTTP requests will not require
###   server urls or header values, only the API endpoint paths.
### Created by: Campbell Guise - cam@guise.co.nz
### Created: 2019-02-17

# -------------------------------------
# Checks the result of an API call (via cURL command) for know HTTP error codes. The
# script can then display a helpful error message and exit gracefully.
# Globals:
#   JAMF_URL
# Arguments:
#   httpMethod - String (GET, PUT, POST or DELETE)
#   httpCode   - HTTP status code returned from API call
#   uriPath    - API endpoint being used in command
#   returnData - Data that was returned from the API call
# Returns:
#   None
# -------------------------------------
function httpStatusCheck () {
	local httpMethod="$1"
	local httpCode="$2"
	local uriPath="$3"
	local returnData="$4"
	
	local jamfError503='[{"healthCode":2,"httpCode":503,"description":"SetupAssistant"}]
' # This output from the Jamf server flows onto a second line
  # The error message has been defined as a variable for easier use

	# If there is any status other than success display the status code and command
	if [[ ${httpCode} -ne 200 && ${httpCode} -ne 201 ]]; then
		echo "Status: $httpCode" >&2
		echo "Command: http ${httpMethod} ${JAMF_URL}/${uriPath}" >&2
	fi
	
	# If the command was successful, do nothing
	if [[ ${httpCode} -eq 200 || ${httpCode} -eq 201 ]]; then
		return 0
		
	# Otherwise display an appropriate error message and exit
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
	elif [ ${httpCode} -eq 409 ]; then
		echo "The the resource you are trying to create already exists or there is a duplicate name" >&2
		exit 1
	elif [[ ${httpCode} -eq 503 && "${returnData}" == "${jamfError503}" ]]; then
		echo "The Jamf API is not finished being provisioned yet for this server: ${JAMF_URL}" >&2
		exit 1
	elif [ ${httpCode} -eq 500 ]; then
		echo "The requested failed due to an internal server error. Check your configuration and try again." >&2
		echo "${returnData}" >&2
		exit 1
	else
		echo "API operation/command failed due to server return code - ${httpCode}" >&2
		echo "${returnData}" >&2
		exit 2
	fi
}

# -------------------------------------
# Performs an HTTP GET request for the specified endpoint on the Jamf Pro API.
# Make sure to pass the full path (including "/JSSResource") to this function.
# This function was inspired by Joshua Roskos & William Smith MacAdmins presentation.
# https://macadmins.psu.edu/2018/05/01/psumac18-263/
# Globals:
#   JAMF_URL
#   HEADER_ACCEPT
#   HEADER_CONTENT_TYPE
#   JAMF_AUTH_KEY
# Arguments:
#   uriPath     - API endpoint to get data from
#   ignoreError - true = Don't exit script for 404 error (used by httpExists function)
# Returns:
#   XML data
# -------------------------------------
function httpGet () {
	local uriPath="${1#/}" # Trim the leading slash if there is one
	local ignoreError="$2"
	
	local returnCode=0
	local result=$( \
	/usr/bin/curl \
		--silent \
		--max-time ${CONNECTION_MAX_TIMEOUT} \
		--request GET \
		--write-out "%{http_code}" \
		--header "${HEADER_ACCEPT}" \
		--header "${HEADER_CONTENT_TYPE}" \
		--url "${JAMF_URL}/${uriPath}" \
		--header "Authorization: Basic ${JAMF_AUTH_KEY}" \
		|| returnCode=$? )
		
	local resultStatus=${result: -3}
	local resultXML=${result%???}
	
	if [ ${returnCode} -eq 0 ]; then
		if [[ "${ignoreError}" != "true" ]]; then
			httpStatusCheck "GET" "${resultStatus}" "${uriPath}" "${resultXML}"
			echo "${resultXML}"
			return 0
		else
			if [[ "${resultStatus}" == '200' ]]; then
				echo "${resultXML}"
				return 0
			elif [[ "${resultStatus}" == '404' ]]; then
				return 1
			else
				httpStatusCheck "GET" "${resultStatus}" "${uriPath}" "${resultXML}"
			fi
		fi
	else
		echo "Curl connection failed with unknown return code ${returnCode}" >&2
		exit 3
	fi
}

# -------------------------------------
# Performs an HTTP GET request for the specified endpoint to check if it exists.
# Make sure to pass the full path (including "/JSSResource") to this function.
# Globals:
#   JAMF_URL
#   HEADER_ACCEPT
#   HEADER_CONTENT_TYPE
#   JAMF_AUTH_KEY
# Arguments:
#   uriPath - API endpoint to check
# Returns:
#   true or false
# -------------------------------------
function httpExists () {
	local uriPath="$1"
	{ # try

		httpGet "${uriPath}" true 2>&1 > /dev/null &&
		# Test passed
		true

	} || { # catch
		# Error in test command
		false
	}
}

# -------------------------------------
# Performs an HTTP PUT request for the specified endpoint on the Jamf Pro API.
# Make sure to pass the full path (including "/JSSResource") to this function.
# This function was inspired by Joshua Roskos & William Smith MacAdmins presentation.
# https://macadmins.psu.edu/2018/05/01/psumac18-263/
# Globals:
#   JAMF_URL
#   HEADER_ACCEPT
#   HEADER_CONTENT_TYPE
#   JAMF_AUTH_KEY
# Arguments:
#   uriPath - API endpoint to send data to
#   xmlData - XML data to be sent via the API
# Returns:
#   XML data
# -------------------------------------
function httpPut () {
	local uriPath="${1#/}" # Trim the leading slash if there is one
	local xmlData="$2"
	
	local returnCode=0
	local result=$( \
	/usr/bin/curl \
		--silent \
		--request PUT \
		--write-out "%{http_code}" \
		--header "${HEADER_ACCEPT}" \
		--header "${HEADER_CONTENT_TYPE}" \
		--url "${JAMF_URL}/${uriPath}" \
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

# -------------------------------------
# Performs an HTTP POST request for the specified endpoint on the Jamf Pro API.
# Make sure to pass the full path (including "/JSSResource") to this function.
# Globals:
#   JAMF_URL
#   HEADER_ACCEPT
#   HEADER_CONTENT_TYPE
#   JAMF_AUTH_KEY
# Arguments:
#   uriPath - API endpoint to send data to
#   xmlData - XML data to be sent via the API
# Returns:
#   XML data
# -------------------------------------
function httpPost () {
	local uriPath="${1#/}" # Trim the leading slash if there is one
	local xmlData="$2"
	
	local returnCode=0
	local result=$( \
	/usr/bin/curl \
		--silent \
		--request POST \
		--write-out "%{http_code}" \
		--header "${HEADER_ACCEPT}" \
		--header "${HEADER_CONTENT_TYPE}" \
		--url "${JAMF_URL}/${uriPath}" \
		--data "${xmlData}" \
		--header "Authorization: Basic ${JAMF_AUTH_KEY}" \
		|| returnCode=$? )
	
	local resultStatus=${result: -3}
	local resultXML=${result%???}
	
	if [ ${returnCode} -eq 0 ]; then
		httpStatusCheck "POST" "${resultStatus}" "${uriPath}" "${resultXML}"
	else
		echo "Curl connection failed with unknown return code ${returnCode}" >&2
		exit 3
	fi
}

# -------------------------------------
# Performs an HTTP DELETE request for the specified endpoint on the Jamf Pro API.
# Make sure to pass the full path (including "/JSSResource") to this function.
# Globals:
#   JAMF_URL
#   HEADER_ACCEPT
#   HEADER_CONTENT_TYPE
#   JAMF_AUTH_KEY
# Arguments:
#   uriPath - API endpoint to be deleted
# Returns:
#   XML data
# -------------------------------------
function httpDelete () {
	local uriPath="${1#/}" # Trim the leading slash if there is one
	
	local returnCode=0
	local result=$( \
	/usr/bin/curl \
		--silent \
		--max-time ${CONNECTION_MAX_TIMEOUT} \
		--request DELETE \
		--write-out "%{http_code}" \
		--header "${HEADER_ACCEPT}" \
		--header "${HEADER_CONTENT_TYPE}" \
		--url "${JAMF_URL}/${uriPath}" \
		--header "Authorization: Basic ${JAMF_AUTH_KEY}" \
		|| returnCode=$? )
		
	local resultStatus=${result: -3}
	local resultXML=${result%???}
	
	if [ ${returnCode} -eq 0 ]; then
		httpStatusCheck "DELETE" "${resultStatus}" "${uriPath}" "${resultXML}"
	else
		echo "Curl connection failed with unknown return code ${returnCode}" >&2
		exit 3
	fi
	
	echo "${resultXML}"
}