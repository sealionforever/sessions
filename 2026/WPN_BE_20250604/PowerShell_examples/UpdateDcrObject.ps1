<#
	The code below ONLY deals with uploading a resource json to Azure in order to properly update the data collection rule.
	As mentioned in the session, it's easiest to get the dcr right the first time. However if changes are still needed, you can use this.

	It requires you to have downloaded the json of the Data Collection Rule.
	It is possible to do so via code, but you also easily copy the resource json from the Azure portal itself.
	There are some properties you will need to remove to make it work properly.
	I've included an example file of what it should look like when you're done.
	Make changes to the local file you want and save the path to the parameter below.

	Make sure that the account with which you log on to the subscription has sufficient access to make the change to the dcr object.
#>


# ENTER YOUR PARAMETERS
$SubscriptionName	= ""	# This should the subscription in which the dcr exists
$DCR_ResourceId		= ""	# This is the resource id of the dcr
$DCR_LocalFilePath	= ""	# This is the local path to the dcr json file you made changes to



# Connect to Azure
Connect-AzAccount -Subscription $SubscriptionName

# Gather DCR json content
$DCR_Content = Get-Content $DCR_LocalFilePath -Raw

# Upload your json file to Azure
Invoke-AzRestMethod -Path ($DCR_ResourceId + "?api-version=2024-03-11") -Method PUT -Payload $DCR_Content

# Disconnect from Azure
Disconnect-AzAccount
