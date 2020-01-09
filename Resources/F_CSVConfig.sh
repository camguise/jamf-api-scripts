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
	
	local csvRequiredHeaders=("App Name" "iTunes URL" "%groups_start%" "%groups_end%")
	local activeAppsHeader="-- Active Apps --"
	local wishlistHeader="-- Wishlist --"
	
	IFS= read -r headerRow < "${csvFile}"
	
	IFS=, read -ra headerFields <<<"${headerRow}"
	headerColsCount="${#headerFields[@]}"
	
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
	
	rowTwoColumnOne=$(sed "2q;d" "${csvFile}" | awk -F, '{ print $1 }')
	
	if [[ "${rowTwoColumnOne}" != "${activeAppsHeader}" ]]; then
		err=true
		echo "Error: No active apps line in row two of the CSV" >&2
	fi
	
	activeApps=()
	while IFS= read -r line; do
		activeApps+=( "$line" )
	done < <( awk "/${activeAppsHeader}/{flag=1; next} /${wishlistHeader}/{flag=0} flag" "${csvFile}" )
	
	activeAppsCount="${#activeApps[@]}"
	
	if [[ ${activeAppsCount} -lt 1 ]]; then
		err=true
		echo "Error: No active apps found in CSV" >&2
	fi
	
	local i=3
	for app in "${activeApps[@]}"; do
		IFS=, read -ra appCols <<<"${app}"
		appColsCount="${#appCols[@]}"
		
		if [[ ${appColsCount} -ne ${headerColsCount} ]]; then
			echo "Error: Row ${i} has ${appColsCount} columns when the header row has ${headerColsCount}"
			err=true
			continue
		fi
		
		appNameIndex=$(getArrayIndex "App Name" "${headerFields[@]}")
		appName="${appCols[${appNameIndex}]}"
		
		if [[ -z "${appName}" ]]; then
			err=true
			echo "Error: Row ${i} has no App Name"
		fi
		
		urlIndex=$(getArrayIndex "iTunes URL" "${headerFields[@]}")
		appUrl="${appCols[${urlIndex}]}"
		
		if [[ -z "${appUrl}" ]]; then
			err=true
			echo "Error: Row ${i} has no iTunes URL"
		fi
		
		if ! regexCheck "$appUrl" "^https:\/\/itunes.apple.com\/nz\/app\/([a-z]|[0-9]|[-!+])+\/id[0-9]+(\?mt=[0-9])?$"; then
			err=true
			echo "Error: Row ${i} has an invalid iTunes URL"
			echo "  ${appUrl}"
		fi
		
		groupStartIndex=$(getArrayIndex "%groups_start%" "${headerFields[@]}")
		groupEndIndex=$(getArrayIndex "%groups_end%" "${headerFields[@]}")
		groupIndex=$((groupStartIndex+1))
		
		echo "Row: ${i}"
		echo "  Name: ${appName}"
		for building in "${buildings[@]}"; do
			buildingIndex=$(getArrayIndex "${building}" "${headerFields[@]}")
			buildingValue="${appCols[${buildingIndex}]}"
			echo "  ${building}: [${buildingValue}]"
		done
		
		((i++))
	done
	
	! $err
}