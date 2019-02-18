### Name: F_General.sh
### Description: General utility functions which are likely to be useful outside of this project
### Created by: Campbell Guise - cam@guise.co.nz
### Updated: 2019-02-17

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
