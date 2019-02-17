### Name: F_XPath.sh
### Description: Various functions used for manipulating or getting information from XML data
### Created by: Campbell Guise - cam@guise.co.nz
### Updated: 2019-02-17

# -------------------------------------
# Get number of rows returned by XPath expression
# Modified slightly from oVirt API scripts
# https://github.com/oVirt/ovirt-site/blob/master/source/develop/api/rest-api/rest-api-using-bash-automation.html.md
# Globals:
#   None
# Arguments:
#   xPath - xml path of items to count
#   data  - xml data to be searched
# Returns:
#   Number of rows matching the given path
# -------------------------------------
function getXPathCount () {
    local xPath="$1"
    local data="$2"
    echo "${data}" | xmllint --xpath "count(${xPath})" -
}

# -------------------------------------
# Get string value of node returned by XPath expression
# Modified slightly from oVirt API scripts
# https://github.com/oVirt/ovirt-site/blob/master/source/develop/api/rest-api/rest-api-using-bash-automation.html.md
# Globals:
#   None
# Arguments:
#   xPath - xml path to desired node
#   data  - xml data to be searched
# Returns:
#   String value found at the requested node
# -------------------------------------
function getXPathValue () {
    local xPath="$1"
    local data="$2"
    echo "${data}" | xmllint --xpath "string(${xPath})" -
}

# -------------------------------------
# Get the value of a key relative to the same level as the specified ID
# Useful to get a name (or other value form an ID)
# New function inspired by oVirt API scripts
# https://github.com/oVirt/ovirt-site/blob/master/source/develop/api/rest-api/rest-api-using-bash-automation.html.md
# Globals:
#   None
# Arguments:
#   searchPath  - xml path to desired node
#   itemID      - ID value to search for
#   returnValue - key of the value to be returned
#   data        - xml data to be searched
# Returns:
#   String value found at the requested node
# -------------------------------------
function getXPathValueFromID () {
	local searchPath="$1"
    local itemID="$2"
    local returnValue="$3"
    local data="$4"
    
    echo "${data}" | xmllint --xpath "string(/${searchPath}[id[text()='$itemID']]/${returnValue})" -
}

# -------------------------------------
# Get an array of IDs from the given XML path
# New function inspired by Joshua Roskos & William Smith MacAdmins presentation
# https://macadmins.psu.edu/2018/05/01/psumac18-263/
# Globals:
#   None
# Arguments:
#   xPath - xml path to desired node
#   data  - xml data to be searched
# Returns:
#   Array of ID values for the specified node
# -------------------------------------
function getXPathIDsFromPath () {
	local xPath="$1"
	local data="$2"
	
	echo "${data}" | /usr/bin/xpath "${xPath}" 2> /dev/null \
	| /usr/bin/perl -lne 'BEGIN{undef $/} while (/<id>(.*?)<\/id>/sg){print $1}'
}
