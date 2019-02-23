### Name: V_Globals.sh
### Description: Global variables to be used in this project 
### Created by: Campbell Guise - cam@guise.co.nz
### Updated: 2019-02-17

## Global Variables ##
# User custom variables
CONNECTION_MAX_TIMEOUT=30 # Seconds before a HTTP connection attempt will timeout

# Static variables
HEADER_CONTENT_TYPE="Content-Type: text/xml"
HEADER_ACCEPT="Accept: text/xml"
CONFIG_REQUIRED_ITEMS=("JAMF_AUTH_KEY" "JAMF_URL")
JAMF_URL_REGEX='^https:\/\/(([a-z]|[0-9])+\.)+([a-z]|[0-9])+:?(8443)?\/?([a-z]|[0-9])+$'

# Placeholder variable names
VERBOSE=false
DRY_RUN=false
OUTPUT_FILE=""
CONFIG_FILE=""
JAMF_AUTH_KEY=""
JAMF_URL=""