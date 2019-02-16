# jamf-api-scripts

Collection of scripts using the Jamf API to simplify repetitive tasks. All scripts use a series of functions inside the Resources folder. These functions perform the actual API tasks on your Jamf Pro server. You must supply a config file to each script but the config file can be created with prompts by using the -o flag.

## updateMobileApps.sh
This script contains a number of variables with can be changed to values which meet the needs of the environment. When run this script will modify all Mobile Device Apps in Jamf to set the values you have specified. E.g. You can say that all apps are to be deployed automatically (rather than via self service), enable VPP license distribution and specify the VPP account to be used.