# jamf-api-scripts

Collection of scripts using the [Jamf Pro](https://www.jamf.com/products/jamf-pro/) API to simplify repetitive tasks. All scripts use a series of functions inside the Resources folder. These functions perform the actual API tasks on your Jamf Pro server. You must supply a config file to each script but the config file can be created with prompts by using the -o flag or the createConfigFile.sh script.

## Scripts

Below is a description of each of the scripts in this project and how they can be used. Each script will have examples of usage and will define which priveileges are required by your API user in Jamf. You should only give your API user the minimum amount of permissions that you require to complete your desired task.

---

### createConfigFile.sh
Create a config file for use with other scripts. You must supply a path to the config file using the -o flag.
#### Usage
When running this command you will be asked to supply the values for server address, api username and api user password.
```console
$ ./createConfigFile.sh -o ~/Downloads/test.cfg
Enter the JSS server address  : https://myserver.jamfcloud.com
Enter your JSS admin username : api-user
Enter your JSS admin password : 

Config file has been written. You can now use this file in other scripts.
 -c /Users/username/Downloads/test.cfg
```
#### Jamf Permissions
No jamf permissions are required to create the config file. The config file will be created using the values you specify even if they are not valid. It is recommended that you test your config file using the `testConfigFile.sh` script before using it with other scripts.

---

### testConfigFile.sh
Test a configuration file. This will check that the file has the appropriate keys defined and also if the script can connect to the specified Jamf Pro server via the API. The server test uses the /JSSResource/buildings endpoint so your api user must have access to this endpoint.
#### Usage
```console
$ ./testConfigFile.sh -c ~/Downloads/test.cfg
Config file is valid
Connection to server https://myserver.jamfcloud.com was successful
```
#### Jamf Permissions
Jamf Pro Server Objects:

| Item      | Create | Read     | Update | Delete |
| --------- |:------:|:--------:|:------:|:------:|
| Buildings | No     | **Yes**  | No     | No     |

---

### updateMobileApps.sh
This script contains a number of variables with can be changed to values which meet the needs of the environment. When run this script will modify all Mobile Device Apps in Jamf to set the values you have specified. E.g. You can say that all apps are to be deployed automatically (rather than via self service), enable VPP license distribution and specify the VPP account to be used.

## License
This project is licensed under the GNU General Public License v3.0. You may use, distribute and copy it under the license terms.
