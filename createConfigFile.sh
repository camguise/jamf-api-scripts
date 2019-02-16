#!/bin/bash

## Source External Files ##
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # parent folder of script
source "${DIR}"/Resources/globals.sh
source "${DIR}"/Resources/functions.sh

## Command line options/arguments ##

# Display help text to describe available command-line options
helpText () {
	echo "Usage: $(basename "$0") [options] -o /OUTPUT/Path/file.cfg
	
-- Create and save Jamf Pro API config file for future use
e.g. $(basename "$0") -v -o ~/Downloads/customer.cfg
	
options:
    -h                show this help text
    -o [file path]    output file for config
    -v                verbose output"
}

while getopts ":o:vh" opt; do
	case $opt in
		o)
			OUTPUT_FILE=$(realpath "$OPTARG")
			;;
		v)
			VERBOSE=true
			;;
		h)
			helpText
			exit 0
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

## MAIN SCRIPT ##

createConfig