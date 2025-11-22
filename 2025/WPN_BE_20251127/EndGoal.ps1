<#
	This is a complete script to perform all tasks that were defined in the MS Graph API session.
	Use this script as a reference or starting point for your own implementations.

	Depends on:
		- Microsoft.Graph.Authentication module
		- An account with appropriate permissions to access the resources in Intune

	Author: Sebastiaan de Wolf
	Version: 1.0
	Date: 2025-11-27
#>


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


# Import the Microsoft Graph module
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph
Connect-MgGraph -NoWelcome
$MgContext = Get-MgContext
Write-Host ""
Write-Host "Connected to Microsoft Graph!" -ForegroundColor Cyan
Write-Host "Account:   " -NoNewline
Write-Host $($MgContext.Account) -ForegroundColor Yellow
Write-Host "Tenant:    " -NoNewline
Write-Host $($MgContext.TenantId) -ForegroundColor Yellow
Write-Host ""

# Prepare empty full report
$FullReport = @()

# Get all noncompliant devices from Intune
$NonCompliantDevices = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=complianceState eq 'noncompliant'&`$select=id, deviceName, complianceState, model, userId, userPrincipalName").value

# Find the broken compliance policies per device
foreach ($Device in $NonCompliantDevices) {
	$Body = @{
		filter = "(DeviceId eq '$($Device.id)') and (PolicyStatus eq '4')"	# 4 = Noncompliant
		select = @("PolicyId", "PolicyName", "PolicyStatus", "DeviceId", "UPN", "LastContact")
	} | ConvertTo-Json

	$Response = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/getDevicePoliciesComplianceReport" -Body $Body
	$BrokenPolicies = Get-ObjectFromReportResponse -Response $Response

	# Find the specific failed settings per broken policy
	foreach ($Policy in $BrokenPolicies) {
		$Body = @{
			filter = "(DeviceId eq '$($Device.id)') and (PolicyId eq '$($Policy.PolicyId)')"	# As discussed in the session, we filter for the noncompliant settings AFTER
			select = @("SettingId", "SettingName", "SettingNm", "SettingStatus", "DeviceId", "PolicyId", "UserId")
		} | ConvertTo-Json

		$Response = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/getDevicePolicySettingsComplianceReport" -Body $Body
		$FailedSettings = Get-ObjectFromReportResponse -Response $Response | Where-Object { $_.SettingStatus -eq '4' }	# 4 = Noncompliant

		# Add all information to the full report
		foreach ($Setting in $FailedSettings) {
			# Build report object
			$ReportObject = [PSCustomObject]@{
				DeviceId			= $Device.id
				DeviceName			= $Device.deviceName
				DeviceModel			= $Device.model
				ComplianceState		= $Device.complianceState
				UserPrincipalName	= $Device.userPrincipalName
				PolicyId			= $Policy.PolicyId
				PolicyName			= $Policy.PolicyName
				PolicyStatus		= $Policy.PolicyStatus
				LastContact			= $Policy.LastContact
				SettingId			= $Setting.SettingId
				SettingName			= $Setting.SettingName
				SettingStatus		= $Setting.SettingStatus
			}
			$FullReport += $ReportObject
		}
	}
}

# Export the full report to a CSV file
$ExportPath = ".\NonCompliantDevicesCustomReport_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$FullReport | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8 -Force
Write-Host ""
Write-Host "Report exported to: " -ForegroundColor Cyan -NoNewline
Write-Host $ExportPath -ForegroundColor Green
Write-Host ""

Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph!" -ForegroundColor Cyan
Write-Host ""
# End of script
