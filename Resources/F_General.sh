### Name: F_General.sh
### Description: General utility functions which are likely to be useful outside of this project
### Created by: Campbell Guise - cam@guise.co.nz
### Created: 2019-02-17

# -------------------------------------
# Requests user input that must match a given regex
# Globals:
#   NONE
# Arguments:
#   requestString  - String to prompt the user for input. Will be printed after the word 'Enter'
#   regexTest      - The regex that the user input must match
#   regexError     - The error to print out if the string does not match the given regex
#   passwordPrompt - true to ask for a password/secret value [Optional]
# Returns:
#   true or false depending on if there is a match
# -------------------------------------
function getUserInputMatchingRegex () {
	local requestString="$1"
	local regexTest="$2"
	local regexError="$3"
	local passwordPrompt="$4"
	
	if [[ "$passwordPrompt" == 'true' ]]; then
		local passwordPrompt=true
	else
		local passwordPrompt=false
	fi
	
	if [ ! -t 0 ]; then
		local pipeIn=true
	else
		local pipeIn=false
	fi
	
	local returnValue=''
	while [[ -z $returnValue ]]; do
		printf "Enter ${requestString} : " >&2
		if $passwordPrompt; then
			read -s tempValue
			echo "" >&2
		else
			read tempValue
			[ ! -t 0 ] && echo "${tempValue}" >&2
		fi
		
		[[ -z "${tempValue}" ]] && echo "Error: You must specify ${requestString}" >&2 && continue
		! regexCheck "${tempValue}" "${regexTest}" && echo "Error: ${regexError}" >&2 && continue
	
		returnValue=${tempValue}
	done
	
	echo -n "${returnValue}"
}

# -------------------------------------
# Checks a string against a given regular expression
# Globals:
#   NONE
# Arguments:
#   checkString - The string to be checked
#   regex       - The regex to be tested
# Returns:
#   true or false depending on if there is a match
# -------------------------------------
regexCheck () {
	local checkString="$1"
	local regex="/${2}/{print \$0}"
	
	regexCheck=$(echo "${checkString}" | awk "!${regex}")
	
	if [[ -z $regexCheck ]]; then
		# Exact match for regex
		true
	else
		false
	fi
}

# -------------------------------------
# Gets the real path to a file relative to root of filesystem /
# Globals:
#   NONE
# Arguments:
#   thePath - The path to be converted to a real path
# Returns:
#   The full path to the file
# -------------------------------------
realPath () {
	local thePath="$1"
    [[ $thePath = /* ]] && echo "$thePath" || echo "$PWD/${thePath#./}"
}

# -------------------------------------
# Echo out the text only if the verbose flag is set
# Globals:
#   VERBOSE
# Arguments:
#   verboseString - The string to be printed
# Returns:
#   None
# -------------------------------------
verbose () {
	local verboseString="$@"
	if $VERBOSE; then
        echo "${verboseString}"
    fi
}

# -------------------------------------
# Ask for confirmation before performing a command. Defaults to YES
# confirmYes "Would you really like to execute?" && command
# Alternatively it can be used in an if statement to determine if multiple commands get run.
# if confirmYes "Would you like to run these commands?"; then
# Globals:
#   None
# Arguments:
#   verboseString - The string to be printed
# Returns:
#   true by default, false for any combination of "NO" (N, n, nO...)
# -------------------------------------
confirmYes () {
	local promptString="${1}"
	
    # call with a prompt string or use a default
    read -r -p "${promptString:-Are you sure?} [Y/n] " response
    case "$response" in
        [nN][oO]|[nN]) 
            false
            ;;
        *)
            true
            ;;
    esac
}

# -------------------------------------
# Ask for confirmation before performing a command. Defaults to NO
# confirmNo "Would you really like to execute?" && command
# Alternatively it can be used in an if statement to determine if multiple commands get run.
# if confirmNo "Would you like to run these commands?"; then
# Globals:
#   None
# Arguments:
#   verboseString - The string to be printed
# Returns:
#   false by default, true for any combination of "YES" (y, Y, yEs...)
# -------------------------------------
confirmNo () {
	local promptString="${1}"
	
    # call with a prompt string or use a default
    read -r -p "${promptString:-Are you sure?} [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

# -------------------------------------
# Check if a value exists in an array
# https://stackoverflow.com/questions/14366390/check-if-an-element-is-present-in-a-bash-array
# Globals:
#   None
# Arguments:
#   seeking - The value to search for
#   in      - The array to be searched for value
# Returns:
#   0 if the value is found, 1 if not
# -------------------------------------
arrayContains () {
    local seeking=$1; shift
    local in=1
    for element; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}
