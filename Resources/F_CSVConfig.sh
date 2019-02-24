### Name: F_CSVConfig.sh
### Description: Functions which process CSV input. There is a template CSV file in the
###   Templates folder. The CSV is taken from a spreadsheet containing the complex
###   formulas for app distribution.
### Created by: Campbell Guise - cam@guise.co.nz
### Created: 2019-02-24

# -------------------------------------
# Checks a CSV to ensure it matches the requirements for jamf-api-scripts
# Globals:
#   NONE
# Arguments:
#   csvFile - The CSV file to be validated
# Returns:
#   true or false depending on if the csv is valid
# -------------------------------------
function validateCSV () {
	local csvFile="$1"
	
	local err=false
	
	if [[ ! -f "${csvFile}" ]]; then
		echo "Error: No CSV file found at ${csvFile}" >&2
		false
		return
	fi
	
	local csvRequiredHeaders=("App Name" "Folder Name" "iTunes URL" "%groups_start%" "%groups_end%")
	
	IFS= read -r headerRow < "${csvFile}"
	
	IFS=, read -ra headerFields <<<"${headerRow}"
	for header in "${csvRequiredHeaders[@]}"; do
		if ! arrayContains "${header}" "${headerFields[@]}"; then
			err=true
			echo "Error: Required CSV header '${header}' not found" >&2
		fi
	done
	
	groupsLine=$(echo "${headerRow}" | awk -F",%groups_start%,|,NULL,|,%groups_end%," '{ print $2; }')
	
	buildings=()
	IFS=, read -ra fields <<<"${groupsLine}"
	for field in "${fields[@]}"; do
		buildings+=("${field}")
	done
	
	buildingsCount="${#buildings[@]}"
	
	if [[ ${buildingsCount} -lt 1 ]]; then
		err=true
		echo "Error: No device groups found in CSV" >&2
	fi
	
	! $err
}