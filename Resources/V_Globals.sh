## Global Variables ##
# User custom variables
CONNECTION_MAX_TIMEOUT=30 # Seconds before the connection attempt will timeout

# Static variables
HEADER_CONTENT_TYPE="Content-Type: text/xml"
HEADER_ACCEPT="Accept: text/xml"
CONFIG_REQUIRED_ITEMS=("JAMF_AUTH_KEY" "JAMF_URL")
set -e # Ensure that script will exit if any of the functions produce a non-zero exit code

# Placeholder variable names
VERBOSE=false
DRY_RUN=false
OUTPUT_FILE=""
CONFIG_FILE=""
JAMF_AUTH_KEY=""
JAMF_URL=""