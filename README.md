# jamf-api-scripts

Collection of scripts using the [Jamf Pro](https://www.jamf.com/products/jamf-pro/) API to simplify repetitive tasks. All scripts use a series of functions inside the Resources folder. These functions perform the actual API tasks on your Jamf Pro server. You must supply a config file to each script but the config file can be created with prompts by using the createConfigFile.sh script.

## Installation
These scripts should work on any standard macOS installation. All scripts in the root directory do depend on the files in the Resources folder so it is best to clone this repository onto your machine and then all required paths are preserved.

Download the scripts to a folder on your computer.
```console
$ cd /path/to/install/directory
$ git clone https://github.com/camguise/jamf-api-scripts.git
Cloning into 'jamf-api-scripts'...
remote: Enumerating objects: 96, done.
remote: Counting objects: 100% (96/96), done.
remote: Compressing objects: 100% (58/58), done.
remote: Total 96 (delta 45), reused 79 (delta 36), pack-reused 0
Unpacking objects: 100% (96/96), done.
```
Then check that the files installed correctly.
```console
$ cd jamf-api-scripts/
$ ls -1
LICENSE
README.md
Resources
bulkChangeMobileApps.sh
createConfigFile.sh
template.cfg
testConfigFile.sh
```
You should now be able to run any of the scripts using the examples below.

## Scripts
Below is a description of each of the scripts in this project and how they can be used. Each script will have examples of usage and will define which priveileges are required by your API user in Jamf. You should only give your API user the minimum amount of permissions that you require to complete your desired task.

---

### createConfigFile.sh
Create a config file for use with other scripts. You must supply a path to the config file using the -o flag.
#### Usage
When running this command you will be asked to supply the values for server address, api username and api user password.
```console
$ ./createConfigFile.sh -o ~/Downloads/test.cfg
Enter Jamf Pro server address : https://server.jamfcloud.com
Enter Jamf Pro API username   : api-user
Enter Jamf Pro API password   : 
Config file has been written. You can now use this file in other scripts.
 -c /Users/username/Downloads/test.cfg
```
#### Jamf Permissions
No jamf permissions are required to create the config file. The config file will be created using the values you specify even if they are not valid. It is recommended that you test your config file using the `testConfigFile.sh` script before using it with other scripts.

---

### testConfigFile.sh
Test a configuration file. This will check that the file has the appropriate keys defined and also if the script can connect to the specified Jamf Pro server via the API. The server test uses the /JSSResource/categories endpoint so your api user must have access to this endpoint.

#### Usage
```console
$ ./testConfigFile.sh -c ~/Downloads/test.cfg
Loading config /Users/username/Downloads/test.cfg...
Config file is valid
Connection to server https://myserver.jamfcloud.com was successful
```
#### Jamf Permissions
##### Jamf Pro Server Objects
| Item       | Create | Read     | Update | Delete |
| ---------- |:------:|:--------:|:------:|:------:|
| Categories | No     | **Yes**  | No     | No     |

---

### bulkChangeMobileApps.sh
This script contains a number of variables with can be changed to values which meet the needs of the environment. When run this script will modify all Mobile Device Apps in Jamf to set the values you have specified. E.g. You can say that all apps are to be deployed automatically (rather than via self service), enable VPP license distribution and specify the VPP account to be used.

#### Usage
Standard use will modify all mobile device apps in your Jamf Pro server
```console
$ ./bulkChangeMobileApps.sh -c ~/Downloads/test.cfg
Classroom............................... [Success]
Facebook................................ [Success]
Google Chrome........................... [Success]
...
Swift Playgrounds....................... [Success]
```
You can choose to supply an include or exclude file which conatains a list of bundle identifiers. You can find the bundle identifiers in Jamf Pro or by executing a curl command to get all app names and bundle IDs via the API. There are example include and exlude files in the Templates folder. Some of these example commands are quite long and you may need to scroll to the right in the code samples below.

Get all app names and bundle IDs
```console
$ /usr/bin/curl https://server.jamfcloud.com/JSSResource/mobiledeviceapplications --silent -u jssadmin | xmllint --format - | grep -E "bundle_id|display_name"
Enter host password for user 'jssadmin': 
    <display_name>Classroom</display_name>
    <bundle_id>com.apple.classroom</bundle_id>
    <display_name>Facebook</display_name>
    <bundle_id>com.facebook.Facebook</bundle_id>
    <display_name>Google Chrome</display_name>
    <bundle_id>com.google.chrome.ios</bundle_id>
    ...
    <display_name>Swift Playgrounds</display_name>
    <bundle_id>com.apple.Playgrounds</bundle_id>
```
Run script with include and exclude files
```console
$ ./bulkChangeMobileApps.sh -c ~/Downloads/test.cfg -v -I ~/Downloads/includeAppsTemplate.txt -E ~/Downloads/excludeAppsTemplate.txt
Loading config /Users/username/Downloads/test.cfg...
Config file is valid
Connection to server https://server.jamfcloud.com was successful
Count:     74
Include:   2
Exclude:   1
Modifying Apps:
Classroom............................... [Success]
Facebook................................ [Exclude]
```

#### Jamf Permissions
##### Jamf Pro Server Objects
| Item               | Create | Read     | Update  | Delete |
| ------------------ |:------:|:--------:|:-------:|:------:|
| Mobile Device Apps | No     | **Yes**  | **Yes** | No     |

---

### getAppList.sh
Compiles a CSV formatted list of all mobile device applications from the given Jamf server. The CSV will have columns for Application Name, URL and Total VPP Licenses. Note: Additional columns may be added in the future and the example below may not reflect the actual output columns. The output has become quite cluttered and doesn't fit nicely in the example.

#### Usage
```console
$ ./getAppList.sh -c ~/Downloads/test.cfg
"App Name","iTunes URL","Total VPP Licenses"
"GarageBand","https://apps.apple.com/nz/app/garageband/id408709785","200"
"iMovie","https://apps.apple.com/nz/app/imovie/id377298193","200"
"ScratchJr","https://apps.apple.com/nz/app/scratchjr/id895485086","200"
```
#### Jamf Permissions
##### Jamf Pro Server Objects
| Item               | Create | Read     | Update | Delete |
| ------------------ |:------:|:--------:|:------:|:------:|
| Mobile Device Apps | No     | **Yes**  | No     | No     |

## License
This project is licensed under the GNU General Public License v3.0. You may use, distribute and copy it under the license terms.
