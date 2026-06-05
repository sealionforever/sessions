# Helper function to deal with Schema/Values report responses
function Get-ObjectFromReportResponse {
	param (
		[Parameter(Mandatory)]
		[object]$Response
	)

	# Prepare ampty return object
	$ReturnObject = @()

	# Retrieve and clean up columns
	$Columns = $Response.Schema.Column
    $Columns = $Columns | ForEach-Object {
        $_.TrimStart('_')
    }

	# Combine columns and values into objects (columns and values have the same index)
	foreach ($Value in $Response.Values) {
        $NewObject = [PSCustomObject]@{}

        0..($Columns.Length-1) | ForEach-Object {
            $i = $_
            $NewObject | Add-Member -MemberType NoteProperty -Name $Columns[$i] -Value $Value[$i]
        }
        $ReturnObject += $NewObject
    }
	
    return $ReturnObject
}



# Import module
Import-Module Microsoft.Graph.DeviceManagement -Force



# Connect to environment
Connect-MgGraph -NoWelcome



# Get devices (simple)
$Devices = Get-MgDeviceManagementManagedDevice
$NonCompliantDevices = $Devices | Where-Object ComplianceState -eq 'noncompliant'



# Get compliance policies (simple)
$CompliancePolicies = Get-MgDeviceManagementDeviceCompliancePolicy



# Get specific broken settings (complex)
$FullReport = @()
### Per device get the compliance policies that are broken
foreach ($d in $NonCompliantDevices) {
	# Create body for report request (get broken compliance policies)
	$Body = @{
		filter = "(DeviceId eq '$($d.id)') and (PolicyStatus eq '4')"	# 4 = Noncompliant
		select = @("PolicyId", "PolicyName", "PolicyStatus", "DeviceId", "UPN", "LastContact")
	} | ConvertTo-Json

	# Get the report from Intune & format it into a usable json object
	$Response = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/getDevicePoliciesComplianceReport" -Body $Body
	$BrokenPolicies = Get-ObjectFromReportResponse -Response $Response

	### Per broken policy get the compliance settings that are broken
	foreach ($p in $BrokenPolicies) {
		# Create body for second report request (get broken compliance policy settings)
		$Body = @{
			filter = "(DeviceId eq '$($d.id)') and (PolicyId eq '$($p.PolicyId)')"
			select = @("SettingId", "SettingName", "SettingNm", "SettingStatus", "DeviceId", "PolicyId", "UserId")
		} | ConvertTo-Json

		# Get the report from Intune & format it into a usable json object
		$Response = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/getDevicePolicySettingsComplianceReport" -Body $Body
		$FailedSettings = Get-ObjectFromReportResponse -Response $Response | Where-Object { $_.SettingStatus -eq '4' }	# 4 = Noncompliant

		### Add all information to the full report
		foreach ($s in $FailedSettings) {
			# Build report object
			$ReportObject = [PSCustomObject]@{
				DeviceId			= $d.id
				DeviceName			= $d.deviceName
				DeviceModel			= $d.model
				ComplianceState		= $d.complianceState
				UserPrincipalName	= $d.userPrincipalName
				PolicyId			= $p.PolicyId
				PolicyName			= $p.PolicyName
				PolicyStatus		= $p.PolicyStatus
				LastContact			= $p.LastContact
				SettingId			= $s.SettingId
				SettingName			= $s.SettingName
				SettingStatus		= $s.SettingStatus
			}
			$FullReport += $ReportObject
		}
	}
}



# Show output
$Devices | Out-GridView
$CompliancePolicies | Out-GridView
$FullReport | Out-GridView



# Disconnect from Graph
Disconnect-MgGraph
